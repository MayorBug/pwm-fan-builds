# LuCI PWM Fan Builds

This repository builds APK releases for PWM Fan Control. It also adds an
optional LuCI updater to the application.

The build uses these sources:

- [pwm-fan-control](https://github.com/MayorBug/packages/tree/pwm-fan-control/utils/pwm-fan-control)
  supplies the controller service and CLI.
- [luci-app-pwm-fan](https://github.com/MayorBug/luci/tree/luci-app-pwm-fan/applications/luci-app-pwm-fan)
  supplies the LuCI application.
- The additional app updater is supplied by this repo.

The workflow resolves each source revision to one commit. It records the
OpenWrt, LuCI-feed, and packages-feed commits in the release metadata.

The LuCI version sets the first release tag. Later builds use a release number
that is one greater than the highest existing `rN` value. The workflow does
not reuse deleted gaps. All three APK packages use the same release number.

Each GitHub release contains these files:

- `pwm-fan-control.apk`
- `luci-app-pwm-fan.apk`
- `luci-app-pwm-fan-updater.apk`
- `sha256sums`
- `latest.json`
- `install.sh`

## Router support

The application can work on other OpenWrt routers with a built in fan. The
device profile must select `kmod-hwmon-pwmfan` by default.

Tested:

- WS1610
- H5000M
- GL.iNet Beryl 7 (`GL-MT3600BE`)

List of other devices that should also work:

- GL-MT3000
- GL-X3000 and GL-XE3000 family
- GL-AXT1800
- AirPi AP3000M
- CF-WR632AX
- Huasifei WH3000 Pro
- Arcadyan Mozart
- SmartRG family

## Installation

Run this command on an APK-based OpenWrt system:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/install.sh | sh
```

The installer downloads all three packages. It compares each file with its
SHA-256 value before installation.
