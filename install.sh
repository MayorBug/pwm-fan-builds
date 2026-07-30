#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

RELEASE_BASE=https://github.com/MayorBug/pwm-fan-builds/releases/latest/download
WORK=

cleanup()
{
	[ -z "$WORK" ] || rm -rf "$WORK"
}

fail()
{
	printf 'pwm-fan installer: %s\n' "$*" >&2
	exit 1
}

trap cleanup EXIT INT TERM
command -v apk >/dev/null 2>&1 ||
	fail 'this community installer supports APK-based OpenWrt only'
command -v wget >/dev/null 2>&1 || fail 'wget is required'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'

WORK=$(mktemp -d /tmp/pwm-fan-install.XXXXXX) ||
	fail 'cannot create a temporary directory'
df -k /tmp | awk 'NR == 2 { exit ($4 < 2048) }' ||
	fail 'at least 2 MiB of free temporary space is required'

for file in pwm-fan-control.apk luci-app-pwm-fan.apk \
	luci-app-pwm-fan-updater.apk sha256sums; do
	wget -q -T 20 -O "$WORK/$file" "$RELEASE_BASE/$file" ||
		fail "could not download $file"
done

(
	cd "$WORK"
	grep -E '^[0-9a-f]{64}  (pwm-fan-control|luci-app-pwm-fan(-updater)?)[.]apk$' \
		sha256sums > checked
	[ "$(wc -l < checked)" -eq 3 ] || exit 1
	sha256sum -c checked
) || fail 'download checksum verification failed'

apk add --allow-untrusted "$WORK/pwm-fan-control.apk" \
	"$WORK/luci-app-pwm-fan.apk" \
	"$WORK/luci-app-pwm-fan-updater.apk" ||
	fail 'APK installation failed'

printf '%s\n' 'PWM Fan Control community packages installed successfully.'
