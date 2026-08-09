#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
WORKFLOW=$ROOT/.github/workflows/build.yml

grep -Fq 'PACKAGES_REPOSITORY: https://github.com/MayorBug/packages' "$WORKFLOW"
grep -Fq 'PACKAGES_BRANCH: pwm-fan-control' "$WORKFLOW"
grep -Fq 'packages-source/utils/pwm-fan-control/Makefile' "$WORKFLOW"
grep -Fq 'existing_releases=$(gh api --paginate' "$WORKFLOW"
grep -Fq 'highest_release=0' "$WORKFLOW"
grep -Fq 'build_release=$((highest_release + 1))' "$WORKFLOW"
grep -Fq 'PKG_RELEASE:=$build_release' "$WORKFLOW"
grep -Fq 'CONTROLLER_RELEASE=$build_release' "$WORKFLOW"
grep -Fq 'package/feeds/packages/pwm-fan-control/compile' "$WORKFLOW"
grep -Fq 'actions/cache/restore@v5' "$WORKFLOW"
grep -Fq 'actions/cache/save@v5' "$WORKFLOW"
grep -Fq 'pwm-fan-dl-v1-${{ runner.os }}-' "$WORKFLOW"
grep -Fq 'pwm-fan-generated-v2-${{ runner.os }}-${{ env.OPENWRT_COMMIT }}-${{ env.CONFIG_HASH }}-' "$WORKFLOW"
grep -Fq 'build_mode:' "$WORKFLOW"
grep -Fq 'default: development' "$WORKFLOW"
grep -Fq -- '- clean-release' "$WORKFLOW"
grep -Fq "if: \${{ inputs.build_mode == 'development' }}" "$WORKFLOW"
grep -Fq 'id: cache-state' "$WORKFLOW"
grep -Fq 'DEVELOPMENT_PREFIX: pwm-fan-generated-v2-${{ runner.os }}-' "$WORKFLOW"
grep -Fq 'EXACT_PREFIX: pwm-fan-generated-v2-${{ runner.os }}-${{ env.OPENWRT_COMMIT }}-${{ env.CONFIG_HASH }}-' "$WORKFLOW"
grep -Fq 'development:"${DEVELOPMENT_PREFIX}"*' "$WORKFLOW"
grep -Fq 'Development build trying older prerequisite cache:' "$WORKFLOW"
grep -Fq 'git -C feeds/luci rev-parse HEAD > ../luci-feed.commit' "$WORKFLOW"
grep -Fq 'git -C feeds/packages rev-parse HEAD > ../packages-feed.commit' "$WORKFLOW"
grep -Fq 'feeds:{luci_commit:$luci_feed_commit' "$WORKFLOW"
grep -Fq 'Clean release build; prerequisites will be rebuilt.' "$WORKFLOW"
grep -Fq "if: \${{ steps.cache-state.outputs.usable != 'true' }}" "$WORKFLOW"
grep -Fq 'CACHE_USABLE: ${{ steps.cache-state.outputs.usable }}' "$WORKFLOW"
grep -Fq 'Cached package build failed; rebuilding generated state.' "$WORKFLOW"
grep -Fq 'rm -rf openwrt/build_dir openwrt/staging_dir openwrt/tmp' "$WORKFLOW"
grep -Fq 'controller_source:' "$WORKFLOW"
grep -Fq 'staging_dir/host/bin/apk --allow-untrusted extract' "$WORKFLOW"
grep -Fq 'test -x "$controller_root/usr/sbin/pwm-fan-control"' "$WORKFLOW"
grep -Fq 'test -f "$core_root/usr/share/rpcd/ucode/pwm.fan"' "$WORKFLOW"
grep -Fq 'test ! -e "$core_root/usr/sbin/pwm-fan-control"' "$WORKFLOW"
grep -Fq 'test -x "$updater_root/usr/libexec/pwm-fan-update"' "$WORKFLOW"
grep -Fq 'test ! -e "$updater_root/usr/sbin/pwm-fan-control"' "$WORKFLOW"
grep -Fq 'uses: actions/upload-artifact@v7' "$WORKFLOW"
grep -Fq 'uses: actions/download-artifact@v8' "$WORKFLOW"
grep -Fq 'persist-credentials: false' "$WORKFLOW"

grep -A3 -F 'restore-keys: |' "$WORKFLOW" |
	grep -Fq 'pwm-fan-generated-v2-${{ runner.os }}-'

build_permissions=$(sed -n '/^  build:/,/^  publish:/p' "$WORKFLOW")
if printf '%s\n' "$build_permissions" | grep -Fq 'contents: write'; then
	echo 'read-only build job has write permission' >&2
	exit 1
fi

publish_permissions=$(sed -n '/^  publish:/,$p' "$WORKFLOW")
printf '%s\n' "$publish_permissions" | grep -Fq 'contents: write'

if grep -Fq 'tar -tf "$controller"' "$WORKFLOW"; then
	echo 'builder still treats APK v3 packages as tar archives' >&2
	exit 1
fi

if grep -Fq 'luci-source/applications/pwm-fan-control' "$WORKFLOW"; then
	echo 'builder still expects the controller in the LuCI repository' >&2
	exit 1
fi

prerequisite_condition=$(sed -n '/name: Build OpenWrt prerequisites/,/run: |/p' "$WORKFLOW")
printf '%s\n' "$prerequisite_condition" |
	grep -Fq "steps.cache-state.outputs.usable != 'true'"

printf 'PWM Fan builder assertions passed.\n'
