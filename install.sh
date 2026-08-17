#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu
umask 077

STABLE_MANIFEST_URL=https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/latest.json
SELF_MANIFEST_URL=@SELF_MANIFEST_URL@
RELEASE_PREFIX=https://github.com/MayorBug/pwm-fan-builds/releases/download/
WORK=
INSTALL_FILES=

cleanup()
{
	[ -z "$WORK" ] || rm -rf "$WORK"
}

fail()
{
	printf 'pwm-fan installer: %s\n' "$*" >&2
	exit 1
}

field()
{
	jsonfilter -i "$1" -e "$2" 2>/dev/null
}

package_version()
{
	local name="$1" version
	version=$(apk list --installed "$name" 2>/dev/null |
		sed -n "1s/^${name}-\\([^ ]*\\).*/\\1/p")
	printf '%s\n' "$version"
}

add_if_needed()
{
	local name="$1" candidate="$2" file="$3" installed relation
	installed=$(package_version "$name")
	if [ -z "$installed" ]; then
		INSTALL_FILES="$INSTALL_FILES $file"
		return
	fi
	relation=$(apk version -t "$installed" "$candidate" 2>/dev/null || printf unknown)
	[ "$relation" != '<' ] || INSTALL_FILES="$INSTALL_FILES $file"
}

fetch_package()
{
	local manifest="$1" key="$2" output="$3" url sha size
	url=$(field "$manifest" "@.packages.$key.url") || fail 'release information is invalid'
	sha=$(field "$manifest" "@.packages.$key.sha256") || fail 'release information is invalid'
	size=$(field "$manifest" "@.packages.$key.size") || fail 'release information is invalid'
	case $url in "$RELEASE_PREFIX"*) ;; *) fail 'release URL is invalid' ;; esac
	case $sha in
		????????????????????????????????????????????????????????????????) ;;
		*) fail 'release checksum is invalid' ;;
	esac
	case $sha in *[!0-9a-f]*) fail 'release checksum is invalid' ;; esac
	case $size in ''|*[!0-9]*) fail 'release size is invalid' ;; esac
	wget -T 20 -O "$output" "$url" || fail "could not download $(basename "$output")"
	[ "$(wc -c < "$output")" -eq "$size" ] || fail 'download size verification failed'
	printf '%s  %s\n' "$sha" "$output" | sha256sum -c - ||
		fail 'download checksum verification failed'
}

trap cleanup EXIT INT TERM
command -v apk >/dev/null 2>&1 || fail 'this installer supports APK-based OpenWrt only'
command -v wget >/dev/null 2>&1 || fail 'wget is required'
command -v jsonfilter >/dev/null 2>&1 || fail 'jsonfilter is required'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'

WORK=$(mktemp -d /tmp/pwm-fan-install.XXXXXX) ||
	fail 'cannot create a temporary directory'
df -k /tmp | awk 'NR == 2 { exit ($4 < 2048) }' ||
	fail 'at least 2 MiB of free temporary space is required'

wget -T 20 -O "$WORK/stable.json" "$STABLE_MANIFEST_URL" ||
	fail 'could not download stable release information'
wget -T 20 -O "$WORK/self.json" "$SELF_MANIFEST_URL" ||
	fail 'could not download build information'
[ "$(field "$WORK/stable.json" '@.channel')" = stable ] ||
	fail 'stable release information is invalid'
[ "$(field "$WORK/self.json" '@.channel')" = stable ] ||
	fail 'build information is invalid'

stable_version=$(field "$WORK/stable.json" '@.version')
stable_release=$(field "$WORK/stable.json" '@.release')
self_version=$(field "$WORK/self.json" '@.version')
self_release=$(field "$WORK/self.json" '@.release')
stable_id=$stable_version-r$stable_release
self_id=$self_version-r$self_release

if [ "$stable_id" = "$self_id" ]; then
	fetch_package "$WORK/self.json" controller "$WORK/controller.apk"
	fetch_package "$WORK/self.json" core "$WORK/core.apk"
	INSTALL_FILES="$WORK/controller.apk $WORK/core.apk"
else
	fetch_package "$WORK/stable.json" controller "$WORK/controller.apk"
	fetch_package "$WORK/stable.json" core "$WORK/core.apk"
	controller_version=$(field "$WORK/stable.json" '@.packages.controller.version')-r$(field "$WORK/stable.json" '@.packages.controller.release')
	core_version=$(field "$WORK/stable.json" '@.packages.core.version')-r$(field "$WORK/stable.json" '@.packages.core.release')
	add_if_needed pwm-fan-control "$controller_version" "$WORK/controller.apk"
	add_if_needed luci-app-pwm-fan "$core_version" "$WORK/core.apk"
fi

fetch_package "$WORK/self.json" updater "$WORK/updater.apk"
INSTALL_FILES="$INSTALL_FILES $WORK/updater.apk"
# The file names contain no shell metacharacters or spaces.
# shellcheck disable=SC2086
apk add --allow-untrusted $INSTALL_FILES || fail 'APK installation failed'

uci -q batch <<-'EOF' || fail 'could not save the stable update channel'
	set pwm_fan_updater.main=updater
	set pwm_fan_updater.main.channel='stable'
	commit pwm_fan_updater
EOF

printf '%s\n' 'PWM Fan packages installed successfully. The update channel is Stable.'
