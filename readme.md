# T480 Smart Battery Priority

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OS: Linux](https://img.shields.io/badge/OS-Linux-blue.svg)](https://www.linux.org/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

A lightweight, safety-focused power management utility for the ThinkPad T480. It enforces charging priority for the external battery (BAT1) while preserving the internal battery (BAT0) as a dedicated UPS buffer.

---

## 🔋 The Problem

The ThinkPad T480 features a bridge battery system. By default, Linux firmware often cycles the internal battery (**BAT0**) aggressively. Since **BAT0** requires opening the chassis to replace and often suffers from poor health over time, it is strategically better to focus wear and tear on the hot-swappable external battery (**BAT1**).

### The Solution:
1.  **Discharge**: Drain **BAT1** first.
2.  **Charge**: Route all power to **BAT1** until it reaches its target threshold.
3.  **Preservation**: Keep **BAT0** at a stable storage level (e.g., 50%) to act as an emergency UPS buffer, preventing it from ever reaching 0% or 100%.

## 🏗️ Architecture

This system operates in user-space using standard Linux kernel interfaces (`sysfs`) and `udev` hardware events.

-   **Trigger**: `udev` detects AC power events or 1% changes in `BAT1` capacity.
-   **Assess**: `smart-battery-priority.sh` compares current `BAT1` levels against TLP thresholds.
-   **Act**: 
    -   `BAT1 < Target`: Issues `inhibit-charge` to `BAT0`. All power is routed to `BAT1`.
    -   `BAT1 >= Target`: Releases `BAT0` to `auto`, allowing it to charge up to its own TLP limit.
    -   `AC Lost`: Immediately releases all inhibits to ensure `BAT0` is available for discharge.

## 📁 Repository Structure

```text
.
├── etc/
│   ├── tlp.conf                         # TLP configuration template
│   └── udev/rules.d/
│       └── 99-smart-battery.rules       # Hardware event triggers (AC & BAT1)
├── usr/local/bin/
│   └── smart-battery-priority.sh        # Core logic state machine
├── AGENTS.md                            # Technical context & safety rules for developers
├── install.sh                           # Deployment script (Dev Mode symlinking)
├── LICENSE                              # MIT License
└── readme.md                            # Project documentation
```

## 🚀 Installation

This project is designed for "Dev Mode" installation using symlinks. This allows logic edits within the repository to take effect immediately on the system.

```bash
# Clone the repository
git clone https://github.com/your-repo/t480-smartbat.git
cd t480-smartbat

# Install via Symlinks
sudo ./install.sh
```

*Note: The installer automatically backups your existing `/etc/tlp.conf` before creating the link.*

## ⚙️ Configuration

Configuration is centralized in `etc/tlp.conf`. The logic script dynamically reads these values:

```ini
# Internal Battery: Storage mode (UPS buffer)
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=50

# External Battery: Primary use
START_CHARGE_THRESH_BAT1=75
STOP_CHARGE_THRESH_BAT1=85  # The script uses this as the trigger point
```

## 🛠️ Monitoring & Debugging

### Real-time Logs
Monitor the state machine as it reacts to power events:
```bash
journalctl -t smartbat -f
```

### Manual Trigger
Force the script to re-evaluate the current state:
```bash
sudo udevadm trigger --subsystem-match=power_supply
```

## ⚠️ Critical Safety Details

-   **Bracket Parsing**: The script uses strict bracket matching (e.g., `[[ "$VAR" == *"[inhibit-charge]"* ]]`) to correctly interpret kernel `charge_behaviour` outputs.
-   **Race Condition Mitigation**: Includes a 2-second delay to allow TLP and the kernel to settle during power transitions.
-   **Loop Prevention**: Udev rules ignore `BAT0` events to avoid recursive triggers.
-   **Idempotency**: Only writes to `sysfs` if the target state differs from the current state to reduce unnecessary disk/bus activity.

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.