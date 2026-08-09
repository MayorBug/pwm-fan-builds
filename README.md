# LuCI PWM Fan Builds

This repository builds three PWM Fan APK packages from these branches:

- `MayorBug/packages:pwm-fan-control` supplies the controller.
- `MayorBug/luci:luci-app-pwm-fan` supplies the LuCI application.

The workflow resolves each source revision to one commit. It records the
OpenWrt, LuCI-feed, and packages-feed commits in the release metadata.

The LuCI version sets the first release tag. Later builds use a release number
that is one greater than the highest existing `rN` value. Deleted gaps are not
reused. All three APK packages use the same release number.

Each GitHub release contains these files:

- `pwm-fan-control.apk`
- `luci-app-pwm-fan.apk`
- `luci-app-pwm-fan-updater.apk`
- `sha256sums`
- `latest.json`
- `install.sh`

## Build modes

Development mode restores the newest Linux build state. This cache can use an
older OpenWrt commit or configuration. The workflow then compiles only the
three PWM Fan packages.

If package compilation fails, the workflow erases the generated build state.
It keeps the download cache. Then it builds the OpenWrt prerequisites and
retries the packages one time.

Clean release mode does not restore generated build state. It builds all
required OpenWrt prerequisites before it compiles the packages.

Both modes use a separate download cache. Every workflow run gets the newest
PWM Fan source commits.

Before publication, the workflow examines the contents of all three APK
packages. The build job has read-only repository access. A separate publish
job creates the GitHub release.

## Installation

Run this command on an APK-based OpenWrt system:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/install.sh | sh
```

The installer downloads all three packages. It compares each file with its
SHA-256 value before installation.
