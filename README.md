# PWM Fan Community Builds

This repository builds community APKs from the latest commit on the
`MayorBug/luci` branch `luci-app-pwm-fan`.

The GitHub Actions workflow is manual-only. The form accepts the OpenWrt ref;
the LuCI source branch is fixed. The release tag and updater package version
come from the controller and LuCI package metadata. Each release records the
resolved LuCI and OpenWrt commit IDs and publishes:

- `pwm-fan-control.apk`
- `luci-app-pwm-fan.apk`
- `luci-app-pwm-fan-updater.apk`
- `sha256sums`
- `latest.json`

The Update page always shows its primary action. A newer release is offered as
**Download new build**. When the installed build matches the release, it shows
**Up to date** and asks for confirmation before reinstalling the same build.
- `install.sh`

## Installation:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/install.sh | sh
```
