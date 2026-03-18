#!/bin/bash
set -euo pipefail

# kiosk.sh — Auto-start Grafana dashboard on the wall screen.
#
# Prerequisites (install on the Pi):
#   sudo apt install -y xorg chromium-browser unclutter
#
# After importing the dashboard in Grafana, replace YOUR_DASHBOARD_ID
# below with the actual dashboard UID (visible in the dashboard URL).
# The default UID in dashboard.json is: air-quality-monitor
#
# Place this file at /home/pi/kiosk.sh and chmod +x it.
# It is launched automatically by kiosk.desktop on login.

DASHBOARD_UID="air-quality-monitor"
GRAFANA_URL="http://localhost:3000/d/${DASHBOARD_UID}/air-quality?kiosk&theme=dark"

# Wait for Grafana to finish starting up before opening the browser.
echo "Waiting for Grafana to be ready..."
sleep 30

# Disable screen blanking and DPMS power-saving (keeps the display always on).
xset s off
xset s noblank
xset -dpms

# Hide the mouse cursor after 1 second of inactivity.
unclutter -idle 1 &

# Open Grafana in full-screen kiosk mode.
# --noerrdialogs and --disable-infobars suppress browser UI noise.
chromium-browser \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --kiosk \
  "${GRAFANA_URL}"
