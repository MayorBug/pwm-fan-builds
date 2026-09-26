# LuCI PWM Fan Builds

Prebuilt APK packages for PWM fan control on APK-based OpenWrt, with Stable and
Development update channels.

<img width="2441" height="2084" alt="PWM Fan LuCI interface" src="https://github.com/user-attachments/assets/5f717dd4-5c17-4e7e-b515-7268abfa35d9" />

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
keeps fan control while the application provides read-only monitoring.

**Tested:**

- WS1610
- H5000M
- GL.iNet Beryl 7 (`GL-MT3600BE`)

**Candidates awaiting device validation:**

- Banana Pi BPI-R3
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

Run on an APK-based OpenWrt router:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/install.sh | sh
```

Choose **Stable** or **Development** when prompted. Stable is selected when no
answer or controlling terminal is available. The installer downloads all three
packages, verifies their SHA-256 checksums, and saves the selected updater
channel.

For unattended installation:

```sh
wget -qO- https://github.com/MayorBug/pwm-fan-builds/releases/latest/download/install.sh | env PWM_FAN_INSTALL_CHANNEL=development sh
```

Use `PWM_FAN_INSTALL_CHANNEL=stable` for unattended Stable installation. The
channel can also be changed later from the LuCI Update page.
