Project Context: T480 Smart Battery Priority

1. Project Goal

Objective: Force the ThinkPad T480 to charge the External Battery (BAT1) first, while keeping the Internal Battery (BAT0) as a dedicated "UPS" buffer. Hardware: ThinkPad T480 (Dual Battery System). Constraint: BAT0 has poor health. It must not be charged to 100%, nor drained to 0%. It acts as an emergency backup only. 2. Architecture & Logic
Core Strategy: The "Inhibit" Pattern

We do not physically disable BAT0. Instead, we use the inhibit-charge kernel command.

    AC Connected:

        If BAT1 < Target (from TLP config): Inhibit BAT0. (All current goes to BAT1).

        If BAT1 >= Target: Release BAT0 to auto. (BAT0 charges only up to its TLP limit).

    AC Disconnected:

        Always set BAT0 to auto (Discharge allowed).

Safety Mechanisms

    TLP Hard Limits: TLP handles the hardware safety net. BAT0 is clamped to 40-50% charge to prevent cell degradation.

    Race Condition Handling: The script waits (sleep 2) on execution to allow TLP to finish its own plug-in routines.

    Loop Prevention: Udev rules only trigger on AC or BAT1 events. Never trigger on BAT0 events to avoid infinite recursion.

3. File Manifest
   File Path Description
   usr/local/bin/smart-battery-priority.sh The Brain. Bash script that reads sensors and toggles charge_behaviour.
   etc/udev/rules.d/99-smart-battery.rules The Trigger. Fires script on AC plug/unplug and BAT1 % change.
   etc/tlp.conf The Safety Net. Defines stop thresholds (BAT0=50%, BAT1=85-95%).
   install.sh Deployment. Symlinks files from this repo to system paths for "Dev Mode".
4. Critical Implementation Details (Do Not Regression)
   A. The "Brackets" Parsing Rule

The kernel outputs charge_behaviour as a list of options with the active one in brackets: [auto] inhibit-charge force-discharge

    Correct Check: if [[ "$CURRENT" == *"[inhibit-charge]"* ]]; then ...

    Incorrect Check: if [[ "$CURRENT" == *"inhibit-charge"* ]]; then ... (Always true because the word exists).

B. Dynamic Thresholds

The script must dynamically fetch STOP_CHARGE_THRESH_BAT1 from tlp-stat -c.

    Fallback: Default to 85 if TLP fetch fails.

    Parsing: Must handle VARIABLE="VALUE" format (strip quotes and variable name).

C. Logging Standard

    Tag: Always use logger -t smartbat.

    Format: DIAGNOSTIC: AC=... | BAT1=...

    Verbosity: Only log ACTION when a change is made. Log NO-OP if state is already correct (to prevent log spam).

5. Development Workflow
   Installation

Use the provided install.sh script. It uses symlinks (ln -sf), so edits in the repo are reflected instantly on the system.
Bash

sudo ./install.sh

Debugging

Monitor the logic in real-time:
Bash

journalctl -t smartbat -f

Verification Commands

    Check Status: tlp-stat -b

    Manual Trigger: sudo udevadm trigger --subsystem-match=power_supply
