#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT INT TERM
mkdir "$TEST_TMP/bin" "$TEST_TMP/files"

printf 'controller\n' > "$TEST_TMP/files/stable-controller.apk"
printf 'core\n' > "$TEST_TMP/files/stable-core.apk"
printf 'stable updater\n' > "$TEST_TMP/files/stable-updater.apk"
printf 'development updater\n' > "$TEST_TMP/files/development-updater.apk"
printf 'development controller\n' > "$TEST_TMP/files/development-controller.apk"
printf 'development core\n' > "$TEST_TMP/files/development-core.apk"

make_manifest()
{
	local output="$1" version="$2" release="$3" prefix="$4" channel="${5:-stable}"
	python3 - "$output" "$version" "$release" "$prefix" "$TEST_TMP/files" "$channel" <<'PY'
import hashlib, json, pathlib, sys
output, version, release, prefix, root, channel = sys.argv[1:]
root = pathlib.Path(root)
packages = {}
names = {
    'controller': f'{prefix}-controller.apk',
    'core': f'{prefix}-core.apk',
    'updater': f'{prefix}-updater.apk',
}
for key, name in names.items():
    data = (root / name).read_bytes()
    packages[key] = {
        'version': version,
        'release': release,
        'url': f'https://github.com/MayorBug/pwm-fan-builds/releases/download/test/{name}',
        'sha256': hashlib.sha256(data).hexdigest(),
        'size': len(data),
    }
pathlib.Path(output).write_text(json.dumps({
    'schema': 1, 'channel': channel, 'version': version,
    'release': release, 'packages': packages,
}))
PY
}

make_manifest "$TEST_TMP/stable.json" 0.3.0 1 stable stable
make_manifest "$TEST_TMP/self.json" 0.4.0 1 development development

cat > "$TEST_TMP/bin/wget" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in
		-O) output=$2; shift 2 ;;
		-T) shift 2 ;;
		*) url=$1; shift ;;
	esac
done
case $url in
	*/latest/download/latest.json) source=$TEST_STABLE_MANIFEST ;;
	*/development/latest.json) source=$TEST_DEVELOPMENT_MANIFEST ;;
	*/stable-controller.apk) source=$TEST_FILES/stable-controller.apk ;;
	*/stable-core.apk) source=$TEST_FILES/stable-core.apk ;;
	*/stable-updater.apk) source=$TEST_FILES/stable-updater.apk ;;
	*/development-updater.apk) source=$TEST_FILES/development-updater.apk ;;
	*/development-controller.apk) source=$TEST_FILES/development-controller.apk ;;
	*/development-core.apk) source=$TEST_FILES/development-core.apk ;;
	*) exit 1 ;;
esac
cp "$source" "$output"
EOF

cat > "$TEST_TMP/bin/jsonfilter" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
	case $1 in
		-i) input=$2; shift 2 ;;
		-e) expression=$2; shift 2 ;;
		*) shift ;;
	esac
done
python3 - "$input" "$expression" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
for key in sys.argv[2].removeprefix('@.').split('.'):
    value = value[key]
print(value)
PY
EOF

cat > "$TEST_TMP/bin/apk" <<'EOF'
#!/bin/sh
case $1 in
	list)
		[ "$TEST_INSTALLED" = yes ] || exit 0
		case $3 in
			pwm-fan-control) printf 'pwm-fan-control-0.3.0-r1 x\n' ;;
			luci-app-pwm-fan) printf 'luci-app-pwm-fan-0.3.0-r1 x\n' ;;
		esac
		;;
	version) printf '=\n' ;;
	add) printf '%s\n' "$*" > "$TEST_APK_LOG" ;;
	*) exit 1 ;;
esac
EOF

cat > "$TEST_TMP/bin/uci" <<'EOF'
#!/bin/sh
cat > "$TEST_UCI_LOG"
EOF
chmod +x "$TEST_TMP/bin/"*
cp "$ROOT/install.sh" "$TEST_TMP/install.sh"
chmod +x "$TEST_TMP/install.sh"

PATH=$TEST_TMP/bin:$PATH \
PWM_FAN_INSTALL_CHANNEL=stable \
TEST_STABLE_MANIFEST=$TEST_TMP/stable.json \
TEST_DEVELOPMENT_MANIFEST=$TEST_TMP/self.json \
TEST_FILES=$TEST_TMP/files TEST_INSTALLED=yes \
TEST_APK_LOG=$TEST_TMP/apk.log TEST_UCI_LOG=$TEST_TMP/uci.log \
	"$TEST_TMP/install.sh" >/dev/null
grep -Fq '/controller.apk' "$TEST_TMP/apk.log"
grep -Fq '/core.apk' "$TEST_TMP/apk.log"
grep -Fq '/updater.apk' "$TEST_TMP/apk.log"
grep -Fq "set pwm_fan_updater.main.channel='stable'" "$TEST_TMP/uci.log"

PATH=$TEST_TMP/bin:$PATH \
PWM_FAN_INSTALL_CHANNEL=development \
TEST_STABLE_MANIFEST=$TEST_TMP/stable.json \
TEST_DEVELOPMENT_MANIFEST=$TEST_TMP/self.json \
TEST_FILES=$TEST_TMP/files TEST_INSTALLED=yes \
TEST_APK_LOG=$TEST_TMP/apk.log TEST_UCI_LOG=$TEST_TMP/uci.log \
	"$TEST_TMP/install.sh" >/dev/null
grep -Fq '/controller.apk' "$TEST_TMP/apk.log"
grep -Fq '/core.apk' "$TEST_TMP/apk.log"
grep -Fq '/updater.apk' "$TEST_TMP/apk.log"
grep -Fq "set pwm_fan_updater.main.channel='development'" "$TEST_TMP/uci.log"

printf 'PWM Fan installer assertions passed.\n'
