#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
UPDATER=$ROOT/luci-app-pwm-fan-updater/root/usr/libexec/pwm-fan-update
VIEW=$ROOT/luci-app-pwm-fan-updater/htdocs/luci-static/resources/view/system/pwm-fan/update.js
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT INT TERM
mkdir "$TEST_TMP/bin"

cat > "$TEST_TMP/bin/uclient-fetch" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in -O) output=$2; shift 2 ;; *) shift ;; esac
done
printf '{}\n' > "$output"
EOF

cat > "$TEST_TMP/bin/jsonfilter" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in -e) expression=$2; shift 2 ;; *) shift ;; esac
done
case $expression in
	'@.schema') printf '1\n' ;;
	'@.channel') printf 'stable\n' ;;
	'@.version') printf '2.0.0\n' ;;
	'@.release') printf '1\n' ;;
	'@.release_notes_url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/tag/v2.0.0-r1\n' ;;
	'@.source.commit') printf '0123456789abcdef0123456789abcdef01234567\n' ;;
	'@.controller_source.commit') printf 'fedcba9876543210fedcba9876543210fedcba98\n' ;;
	'@.packages.controller.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/pwm-fan-control.apk\n' ;;
	'@.packages.core.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/luci-app-pwm-fan.apk\n' ;;
	'@.packages.updater.url') printf 'https://github.com/MayorBug/pwm-fan-builds/releases/download/v2.0.0-r1/luci-app-pwm-fan-updater.apk\n' ;;
	'@.packages.controller.sha256'|'@.packages.core.sha256'|'@.packages.updater.sha256')
		printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' ;;
	'@.packages.controller.size'|'@.packages.core.size'|'@.packages.updater.size') printf '100\n' ;;
	*) exit 1 ;;
esac
EOF

cat > "$TEST_TMP/bin/apk" <<'EOF'
#!/bin/sh
case $1 in
	list) [ -z "${TEST_INSTALLED:-}" ] || printf 'luci-app-pwm-fan-%s x\n' "$TEST_INSTALLED" ;;
	info) ;;
	version) printf '%s\n' "$TEST_RELATION" ;;
	*) exit 1 ;;
esac
EOF
chmod +x "$TEST_TMP/bin/"*

check_case()
{
	TEST_INSTALLED=$1 TEST_RELATION=$2 \
	PWM_FAN_UPDATE_HTTP_CLIENT=$TEST_TMP/bin/uclient-fetch \
	PWM_FAN_UPDATE_JSONFILTER=$TEST_TMP/bin/jsonfilter \
	PWM_FAN_UPDATE_APK=$TEST_TMP/bin/apk \
		"$UPDATER" check > "$TEST_TMP/result.json"
	python3 - "$TEST_TMP/result.json" "$3" "$4" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value['success'] is True
assert value['update_available'] is (sys.argv[2] == 'true')
assert value['same_version'] is (sys.argv[3] == 'true')
assert value['controller_source_commit'] == 'fedcba9876543210fedcba9876543210fedcba98'
PY
}

check_case 1.9.0-r2 '<' true false
check_case 2.0.0-r1 '=' false true
check_case 2.1.0-r1 '>' false false

grep -Fq "_('Download new build')" "$VIEW"
grep -Fq "_('Up to date')" "$VIEW"
grep -Fq "_('Reinstall current build?')" "$VIEW"
grep -Fq "_('Controller source commit')" "$VIEW"
grep -Fq "method: 'status'" "$VIEW"
grep -Fq "E('progress'" "$VIEW"
grep -Fq "_('Files: %d of %d')" "$VIEW"
grep -Fq "_('Reconnecting to updater…')" "$VIEW"
grep -Fq "_('Checking for updates…')" "$VIEW"
grep -Fq 'load: function() {' "$VIEW"
grep -Fq 'return Promise.resolve();' "$VIEW"
grep -Fq 'callCheck().then(function(status)' "$VIEW"
grep -Fq 'if (++reconnectAttempts > 40)' "$VIEW"
grep -Fq 'overall * 100 / count' "$VIEW"
grep -Fq 'return delay().then(pollStatus)' "$VIEW"
grep -Fq -- '--force-reinstall' "$UPDATER"
grep -Fq 'list --installed luci-app-pwm-fan' "$UPDATER"
if grep -Fq 'list --installed -q luci-app-pwm-fan' "$UPDATER"; then
	echo 'installed version lookup still suppresses package version output' >&2
	exit 1
fi
grep -Fq 'status) read_status' "$UPDATER"
grep -Fq 'STATUS_PHASE=downloading' "$UPDATER"
grep -Fq 'wc -c < "$WORK/$name"' "$UPDATER"

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

if grep -Eq 'wget[[:space:]]+-q' "$ROOT/install.sh"; then
	echo 'installer still suppresses wget download progress' >&2
	exit 1
fi

printf 'PWM Fan updater assertions passed.\n'
