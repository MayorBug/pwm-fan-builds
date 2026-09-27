#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu
umask 077

STABLE_MANIFEST_URL=https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/latest.json
DEVELOPMENT_MANIFEST_URL=https://github.com/MayorBug/pwm-fan-builds/releases/download/development/latest.json
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

valid_version()
{
	case $1 in ''|*[!0-9A-Za-z.+_-]*) return 1 ;; *) return 0 ;; esac
}

valid_release()
{
	case $1 in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

validate_manifest()
{
	local manifest=$1 version release key package_version package_release
	[ "$(field "$manifest" '@.schema')" = 1 ] || return 1
	version=$(field "$manifest" '@.version') || return 1
	release=$(field "$manifest" '@.release') || return 1
	valid_version "$version" && valid_release "$release" || return 1
	for key in controller core updater; do
		package_version=$(field "$manifest" "@.packages.$key.version") || return 1
		package_release=$(field "$manifest" "@.packages.$key.release") || return 1
		[ "$package_version" = "$version" ] && [ "$package_release" = "$release" ] || return 1
	done
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

install_channel=${PWM_FAN_INSTALL_CHANNEL:-}
if [ -z "$install_channel" ]; then
	choice=
	if printf '%s' 'Install Stable or Development? [S/d]: ' > /dev/tty 2>/dev/null; then
		IFS= read -r choice < /dev/tty || choice=
	fi
	case $choice in d|D|dev|Dev|development|Development|2) install_channel=development ;; *) install_channel=stable ;; esac
fi
case $install_channel in
	stable) manifest_url=$STABLE_MANIFEST_URL; channel_label=Stable ;;
	development) manifest_url=$DEVELOPMENT_MANIFEST_URL; channel_label=Development ;;
	*) fail 'PWM_FAN_INSTALL_CHANNEL must be stable or development' ;;
esac

wget -T 20 -O "$WORK/selected.json" "$manifest_url" ||
	fail "could not download $install_channel release information"
[ "$(field "$WORK/selected.json" '@.channel')" = "$install_channel" ] ||
	fail "$install_channel release information is invalid"
validate_manifest "$WORK/selected.json" ||
	fail "$install_channel release package versions are invalid"

fetch_package "$WORK/selected.json" controller "$WORK/controller.apk"
fetch_package "$WORK/selected.json" core "$WORK/core.apk"
fetch_package "$WORK/selected.json" updater "$WORK/updater.apk"
INSTALL_FILES="$WORK/controller.apk $WORK/core.apk $WORK/updater.apk"
# The file names contain no shell metacharacters or spaces.
# shellcheck disable=SC2086
apk add --allow-untrusted $INSTALL_FILES || fail 'APK installation failed'

uci -q batch <<-EOF || fail "could not save the $install_channel update channel"
	set pwm_fan_updater.main=updater
	set pwm_fan_updater.main.channel='$install_channel'
	commit pwm_fan_updater
EOF

printf 'PWM Fan packages installed successfully. The update channel is %s.\n' "$channel_label"
