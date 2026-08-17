# LuCI PWM Fan Builds

This repository builds APK releases for PWM Fan Control. It also adds an
optional LuCI updater with Stable and Development channels.

<img width="2441" height="2084" alt="image" src="https://github.com/user-attachments/assets/5f717dd4-5c17-4e7e-b515-7268abfa35d9" />

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

New builds first appear as GitHub prereleases. The Development channel shows
the newest prerelease. The Stable channel does not show a prerelease.

After a device test, run the **Promote PWM Fan Build** workflow. Enter the
tested tag, such as `v0.4.0-r1`. Promotion marks the same APK files as Stable.
It does not rebuild the packages.

Each GitHub release contains these files:

- `pwm-fan-control.apk`
- `luci-app-pwm-fan.apk`
- `luci-app-pwm-fan-updater.apk`
- `sha256sums`
- `latest.json`
- `install.sh`

## Router support

A fan in the router does not by itself make the router compatible.

A compatible router has these items:

- a device-tree `pwm-fan` device
- a writable PWM output through Linux hwmon
- a readable CPU thermal zone
- a thermal cooling policy that uses the PWM fan

Tested:

- WS1610
- H5000M
- GL.iNet Beryl 7 (`GL-MT3600BE`)

Untested candidates:

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

## Test a development build

Open the required prerelease and copy its direct installer command. Example:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/download/v0.4.0-r1/install.sh | sh
```

Before promotion, this installer keeps the stable controller and LuCI app. It
installs the new channel-aware updater. Open the Update page and select
**Development** to install the complete prerelease.

The updater saves the selected channel on the router. Select **Stable** to
return to normal update checks. The updater does not offer an automatic
downgrade when the installed development build is newer than Stable.
