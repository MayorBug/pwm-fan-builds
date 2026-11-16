#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
UPDATER=${PWM_TEST_UPDATER:-$ROOT/luci-app-pwm-fan-updater/root/usr/libexec/pwm-fan-update}
VIEW=$ROOT/luci-app-pwm-fan-updater/htdocs/luci-static/resources/view/system/pwm-fan/update.js
RPCD=$ROOT/luci-app-pwm-fan-updater/root/usr/share/rpcd/ucode/pwm.fan.update
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT INT TERM
mkdir "$TEST_TMP/bin"
export PWM_FAN_UPDATE_LOCK=$TEST_TMP/lock

cat > "$TEST_TMP/bin/uclient-fetch" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in -O) output=$2; shift 2 ;; *) shift ;; esac
done
if [ "${TEST_KILL_UPDATER:-no}" = yes ]; then
	kill -KILL "$PPID"
	exit 1
fi
if [ "${TEST_VALID_PACKAGE:-no}" = yes ]; then
	printf '%0100d' 0 > "$output"
else
	printf '{}\n' > "$output"
fi
EOF

cat > "$TEST_TMP/bin/jsonfilter" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in -e) expression=$2; shift 2 ;; *) shift ;; esac
done
case $expression in
	'@.schema') printf '1\n' ;;
	'@.channel') printf '%s\n' "${TEST_MANIFEST_CHANNEL:-stable}" ;;
	'@.version') printf '2.0.0\n' ;;
	'@.release') printf '1\n' ;;
	'@.packages.controller.version') printf '%s\n' "${TEST_CONTROLLER_MANIFEST_VERSION:-2.0.0}" ;;
	'@.packages.core.version'|'@.packages.updater.version') printf '2.0.0\n' ;;
	'@.packages.controller.release'|'@.packages.core.release'|'@.packages.updater.release') printf '1\n' ;;
	'@.release_notes_url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/tag/v2.0.0-r1\n' ;;
	'@.source.commit') printf '0123456789abcdef0123456789abcdef01234567\n' ;;
	'@.controller_source.commit') printf 'fedcba9876543210fedcba9876543210fedcba98\n' ;;
	'@.packages.controller.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/pwm-fan-control.apk\n' ;;
	'@.packages.core.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/luci-app-pwm-fan.apk\n' ;;
	'@.packages.updater.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/luci-app-pwm-fan-updater.apk\n' ;;
	'@.packages.controller.sha256'|'@.packages.core.sha256'|'@.packages.updater.sha256')
		printf '%s\n' "${TEST_SHA:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}" ;;
	'@.packages.controller.size'|'@.packages.core.size'|'@.packages.updater.size') printf '100\n' ;;
	*) exit 1 ;;
esac
EOF

cat > "$TEST_TMP/bin/uci" <<'EOF'
#!/bin/sh
case $* in
	'-q get pwm_fan_updater.main.channel') printf '%s\n' "${TEST_CHANNEL:-stable}" ;;
	'-q batch') cat > "${TEST_UCI_LOG:-/dev/null}" ;;
	*) exit 1 ;;
esac
EOF

cat > "$TEST_TMP/bin/apk" <<'EOF'
#!/bin/sh
case $1 in
	list)
		package=$3
		case $package in
			luci-app-pwm-fan) version=${TEST_INSTALLED:-} ;;
			pwm-fan-control) version=${TEST_CONTROLLER_INSTALLED:-${TEST_INSTALLED:-}} ;;
			luci-app-pwm-fan-updater) version=${TEST_UPDATER_INSTALLED:-${TEST_INSTALLED:-}} ;;
		esac
		[ -z "$version" ] || printf '%s-%s x\n' "$package" "$version" ;;
	info) ;;
	version) printf '%s\n' "$TEST_RELATION" ;;
	add) [ -n "${TEST_APK_LOG:-}" ] && printf '%s\n' "$*" > "$TEST_APK_LOG" ;;
	*) exit 1 ;;
esac
EOF
chmod +x "$TEST_TMP/bin/"*

check_case()
{
	TEST_INSTALLED=$1 TEST_CONTROLLER_INSTALLED=${6:-$1} \
	TEST_UPDATER_INSTALLED=${7:-$1} TEST_RELATION=$2 TEST_CHANNEL=$5 TEST_MANIFEST_CHANNEL=$5 \
	PWM_FAN_UPDATE_HTTP_CLIENT=$TEST_TMP/bin/uclient-fetch \
	PWM_FAN_UPDATE_JSONFILTER=$TEST_TMP/bin/jsonfilter \
	PWM_FAN_UPDATE_APK=$TEST_TMP/bin/apk \
	PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci \
		"$UPDATER" check > "$TEST_TMP/result.json"
	python3 - "$TEST_TMP/result.json" "$3" "$4" "$5" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value['success'] is True
assert value['update_available'] is (sys.argv[2] == 'true')
assert value['same_version'] is (sys.argv[3] == 'true')
assert value['controller_source_commit'] == 'fedcba9876543210fedcba9876543210fedcba98'
assert value['channel'] == sys.argv[4]
PY
}

check_case 1.9.0-r2 '<' true false stable
check_case 2.0.0-r1 '=' false true stable
check_case 2.1.0-r1 '>' false false stable
check_case 1.9.0-r2 '<' true false development
check_case 2.0.0-r1 '=' true false stable 1.9.0-r2 2.0.0-r1
if TEST_CONTROLLER_MANIFEST_VERSION=1.9.0 TEST_INSTALLED=2.0.0-r1 \
	TEST_RELATION='=' TEST_CHANNEL=stable TEST_MANIFEST_CHANNEL=stable \
	PWM_FAN_UPDATE_HTTP_CLIENT=$TEST_TMP/bin/uclient-fetch \
	PWM_FAN_UPDATE_JSONFILTER=$TEST_TMP/bin/jsonfilter \
	PWM_FAN_UPDATE_APK=$TEST_TMP/bin/apk PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci \
	"$UPDATER" check > "$TEST_TMP/mismatch.json"; then
	echo 'updater accepted mismatched manifest package versions' >&2
	exit 1
fi
grep -Fq 'manifest_version_mismatch' "$TEST_TMP/mismatch.json"

grep -Fq -- '--force-reinstall' "$UPDATER"
grep -Fq 'installed_version luci-app-pwm-fan' "$UPDATER"
grep -Fq 'installed_version pwm-fan-control' "$UPDATER"
grep -Fq 'installed_version luci-app-pwm-fan-updater' "$UPDATER"
if grep -Fq 'list --installed -q' "$UPDATER"; then
	echo 'installed version lookup still suppresses package version output' >&2
	exit 1
fi
grep -Fq 'withTimeout(callCheck(), 30000)' "$VIEW"
grep -Fq 'withTimeout(callSetChannel(value), 10000)' "$VIEW"
grep -Fq 'request?.args?.channel' "$RPCD"
if grep -Fq 'request?.channel' "$RPCD"; then
	echo 'rpcd channel handler reads the wrong request level' >&2
	exit 1
fi
grep -Fq '/etc/config/pwm_fan_updater' "$ROOT/luci-app-pwm-fan-updater/Makefile"
grep -Fq "option channel 'stable'" \
	"$ROOT/luci-app-pwm-fan-updater/root/etc/config/pwm_fan_updater"

TEST_CHANNEL=development TEST_UCI_LOG=$TEST_TMP/uci.log \
PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci \
	"$UPDATER" channel-get > "$TEST_TMP/channel.json"
grep -Fq '"channel":"development"' "$TEST_TMP/channel.json"
TEST_UCI_LOG=$TEST_TMP/uci.log PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci \
	"$UPDATER" channel-set development > "$TEST_TMP/channel-set.json"
grep -Fq '"success":true' "$TEST_TMP/channel-set.json"
grep -Fq "set pwm_fan_updater.main.channel='development'" "$TEST_TMP/uci.log"
if PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci "$UPDATER" channel-set invalid \
	> "$TEST_TMP/invalid-channel.json"; then
	echo 'invalid update channel was accepted' >&2
	exit 1
fi
grep -Fq '"error":"invalid_channel"' "$TEST_TMP/invalid-channel.json"

status_file=$TEST_TMP/status.json
PWM_FAN_UPDATE_STATUS=$status_file "$UPDATER" status > "$TEST_TMP/status-result.json"
python3 - "$TEST_TMP/status-result.json" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value['running'] is False
assert value['phase'] == 'idle'
assert value['package_count'] == 3
PY

PWM_FAN_UPDATE_STATUS=$status_file \
PWM_FAN_UPDATE_HTTP_CLIENT=$TEST_TMP/bin/uclient-fetch \
PWM_FAN_UPDATE_JSONFILTER=$TEST_TMP/bin/jsonfilter \
PWM_FAN_UPDATE_APK=$TEST_TMP/bin/apk \
PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci \
	"$UPDATER" install > "$TEST_TMP/start-result.json"
python3 - "$TEST_TMP/start-result.json" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value == {'success': True, 'started': True}
PY
for _attempt in $(seq 1 30); do
	PWM_FAN_UPDATE_STATUS=$status_file "$UPDATER" status > "$TEST_TMP/status-result.json"
	grep -Fq '"running":false' "$TEST_TMP/status-result.json" && break
	sleep 0.1
done
python3 - "$TEST_TMP/status-result.json" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value['running'] is False
assert value['success'] is False
assert value['phase'] == 'failed'
assert value['error'] == 'package_size_mismatch'
assert value['package'] == 'controller.apk'
PY

# A successful async update must install all three verified packages.
export PWM_FAN_UPDATE_STATUS=$status_file
export PWM_FAN_UPDATE_HTTP_CLIENT=$TEST_TMP/bin/uclient-fetch
export PWM_FAN_UPDATE_JSONFILTER=$TEST_TMP/bin/jsonfilter
export PWM_FAN_UPDATE_APK=$TEST_TMP/bin/apk
export PWM_FAN_UPDATE_UCI=$TEST_TMP/bin/uci
export TEST_SHA=$(printf '%0100d' 0 | sha256sum | cut -d' ' -f1)
export TEST_VALID_PACKAGE=yes
export TEST_APK_LOG=$TEST_TMP/apk.log
wait_finished()
{
	for _attempt in $(seq 1 100); do
		"$UPDATER" status > "$TEST_TMP/finished.json"
		grep -Fq '"running":false' "$TEST_TMP/finished.json" && return 0
		sleep 0.1
	done
	cat "$TEST_TMP/finished.json" >&2
	return 1
}
"$UPDATER" install > /dev/null
wait_finished
python3 - "$TEST_TMP/finished.json" <<'PYTEST'
import json, pathlib, sys
status = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert status['success'] is True and status['phase'] == 'complete', status
assert status['completed'] == 3
PYTEST
grep -Fq -- '--force-reinstall' "$TEST_APK_LOG"
for package in controller core updater; do
	grep -Fq "/$package.apk" "$TEST_APK_LOG"
done

# A killed worker must become a failed operation, then permit another install.
TEST_KILL_UPDATER=yes "$UPDATER" install > /dev/null
wait_finished
grep -Fq '"error":"update_interrupted"' "$TEST_TMP/finished.json"
"$UPDATER" install > /dev/null
wait_finished
grep -Fq '"success":true' "$TEST_TMP/finished.json"

# Reused PIDs must not preserve a stale lock. A live matching identity must.
mkdir "$PWM_FAN_UPDATE_LOCK"
mkdir "$PWM_FAN_UPDATE_LOCK/owner.$$.0"
"$UPDATER" status > "$TEST_TMP/reused-pid.json"
grep -Fq '"error":"update_interrupted"' "$TEST_TMP/reused-pid.json"
[ ! -d "$PWM_FAN_UPDATE_LOCK" ]
stat=$(cat /proc/$$/stat)
stat=${stat##*) }
identity=$(printf '%s\n' "$stat" | awk '{print $20}')
mkdir "$PWM_FAN_UPDATE_LOCK"
mkdir "$PWM_FAN_UPDATE_LOCK/owner.$$.$identity"
if "$UPDATER" install > "$TEST_TMP/locked.json"; then
	echo 'updater accepted an install while a live owner held the lock' >&2
	exit 1
fi
grep -Fq 'update_in_progress' "$TEST_TMP/locked.json"
rmdir "$PWM_FAN_UPDATE_LOCK/owner.$$.$identity" "$PWM_FAN_UPDATE_LOCK"

if grep -Eq 'wget[[:space:]]+-q' "$ROOT/install.sh"; then
	echo 'installer still suppresses wget download progress' >&2
	exit 1
fi
grep -Fq 'STABLE_MANIFEST_URL=' "$ROOT/install.sh"
grep -Fq 'DEVELOPMENT_MANIFEST_URL=' "$ROOT/install.sh"
grep -Fq 'Install Stable or Development? [S/d]:' "$ROOT/install.sh"
grep -Fq 'PWM_FAN_INSTALL_CHANNEL' "$ROOT/install.sh"
grep -Fq 'fetch_package "$WORK/selected.json" controller' "$ROOT/install.sh"
grep -Fq 'fetch_package "$WORK/selected.json" core' "$ROOT/install.sh"
grep -Fq 'fetch_package "$WORK/selected.json" updater' "$ROOT/install.sh"
grep -Fq "set pwm_fan_updater.main.channel='\$install_channel'" "$ROOT/install.sh"

printf 'PWM Fan updater assertions passed.\n'
