# LuCI PWM Fan Builds

Prebuilt APK packages for PWM fan control on APK-based OpenWrt, with Stable and
Development update channels.

## Gallery

Click a screenshot to open the full image. These screenshots show the Development interface.

| Monitoring and history | General settings | Fan curve |
| --- | --- | --- |
| [![Fan monitoring and temperature history](docs/images/monitoring.png)](docs/images/monitoring.png) | [![Operating mode and automatic control settings](docs/images/settings.png)](docs/images/settings.png) | [![Fan curve editor and kernel minimum](docs/images/fan-curve.png)](docs/images/fan-curve.png) |


## What it builds

Each release contains:

- `pwm-fan-control.apk` — controller service and CLI from
  [`MayorBug/packages`](https://github.com/MayorBug/packages/tree/pwm-fan-control/utils/pwm-fan-control)
- `luci-app-pwm-fan.apk` — LuCI interface from
  [`MayorBug/luci`](https://github.com/MayorBug/luci/tree/luci-app-pwm-fan/applications/luci-app-pwm-fan)
- `luci-app-pwm-fan-updater.apk` — Stable/Development updater from this repository
- `sha256sums`, `latest.json`, and `install.sh`

The build records the exact OpenWrt, source, LuCI-feed, and packages-feed commits
in `latest.json`.

- `main` builds Stable releases tagged `vVERSION-rN`.
- `dev` builds Development prereleases tagged `vVERSION-dev-rN`.

## Router support

A router needs all of the following:

- a device-tree `pwm-fan` device
- writable PWM through Linux hwmon
- a readable CPU thermal zone
- a thermal cooling policy connected to the fan

Ascending and electrically inverted monotonic `cooling-levels` are supported.
If hardware is found but its policy cannot be normalized safely, the kernel
keeps fan control while the application provides read-only monitoring. Version
1.1 can also use an optional MediaTek Wi-Fi hwmon temperature in Auto and Curve.
Controller, LuCI, and updater packages are released and installed as one matched set.

**Tested:**

- WS1610
- H5000M
- GL.iNet Beryl 7 (`GL-MT3600BE`)
- Banana Pi BPI-R3

**Candidates awaiting device validation:**

- GL-MT3000
- GL-X3000 / GL-XE3000 family
- GL-AXT1800
- AirPi AP3000M
- CF-WR632AX
- Huasifei WH3000 Pro
- Arcadyan Mozart
- SmartRG family

A fan connector alone does not guarantee compatibility.

## Installation

The Development installer and updater require `curl`. If it is missing, run `apk add curl` on your router first.
This change addresses a GitHub download failure seen with OpenWrt's `wget` (`uclient-fetch`):
```text
Connection error: Connection timed out
```
Run this command on your router through SSH:
```sh
curl -fsSL --connect-timeout 30 --max-time 60 -o /tmp/pwm-fan-install.sh https://github.com/MayorBug/pwm-fan-builds/releases/download/development/install.sh && PWM_FAN_INSTALL_CHANNEL=development sh /tmp/pwm-fan-install.sh
```
