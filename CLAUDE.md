# CLAUDE.md

This file gives Claude Code full context about the `home-air-monitor` project. Read this before making any changes.

---

## Project summary

A DIY multi-room air quality monitoring system for a small apartment. ESP32 microcontroller nodes report CO₂, temperature, humidity, and VOC data to a self-hosted Raspberry Pi running Home Assistant, InfluxDB, and Grafana. A wall-mounted touchscreen shows a live dashboard. The same dashboard is accessible remotely on a phone via Tailscale. Smart plugs automate air purifiers based on sensor readings. No cloud services, no subscriptions.

---

## Hardware

### Raspberry Pi hub
- **Raspberry Pi 4 Model B (1GB)** running Raspberry Pi OS Lite (64-bit)
- Static local IP: configured by user (see `docs/SOFTWARE.md`)
- Services running: Home Assistant (port 8123), InfluxDB v2 (port 8086), Grafana (port 3000)
- Connected to: 10.1" HDMI touchscreen mounted on wall

### Sensor nodes
Three ESP32-C3 Super Mini boards, each in a Hammond 1591XXSSBK enclosure, powered via USB-C:

| Node name | Room | Sensors |
|---|---|---|
| `bedroom-sensor` | Bedroom | SCD40 (CO₂ + temp + humidity) |
| `livingroom-sensor` | Living room | SCD40 (CO₂ + temp + humidity) |
| `kitchen-sensor` | Kitchen | SCD40 (CO₂ + temp + humidity) + SGP40 (VOC index) |

Sensors connect to the ESP32 via STEMMA QT / Qwiic JST-SH cables — no soldering, I2C bus.

### Smart plugs
- 2× Sonoff S31 running **Tasmota firmware** (local MQTT, no cloud)
- Controlled by Home Assistant automations
- One per air purifier

---

## Software stack

| Software | Version target | Role |
|---|---|---|
| Raspberry Pi OS Lite | 64-bit, Bookworm | OS |
| Home Assistant Supervised | Latest | Sensor hub, automation engine |
| ESPHome (HA add-on) | Latest | ESP32 firmware via YAML |
| InfluxDB | v2 | Time-series sensor data storage |
| Grafana | Latest stable | Dashboard (wall screen + phone) |
| Tailscale | Latest | Secure remote access, no port forwarding |

**All software is free and open source. No cloud dependencies after initial Tailscale auth.**

---

## Repo structure

```
home-air-monitor/
├── CLAUDE.md                        # This file
├── README.md                        # Project overview
├── docs/
│   ├── PARTS.md                     # Full hardware parts list
│   └── SOFTWARE.md                  # Step-by-step setup guide
├── esphome/
│   ├── secrets.yaml                 # WiFi/API keys — GITIGNORED, never commit
│   ├── bedroom-sensor.yaml          # ESPHome config: bedroom node
│   ├── livingroom-sensor.yaml       # ESPHome config: living room node
│   └── kitchen-sensor.yaml          # ESPHome config: kitchen node (SCD40 + SGP40)
├── home-assistant/
│   ├── configuration.yaml           # HA config: InfluxDB integration + filters
│   └── automations/
│       ├── purifier-voc.yaml        # Auto-control purifiers based on VOC
│       ├── purifier-co2.yaml        # Auto-control purifiers based on CO₂
│       └── alerts.yaml              # Phone notifications for threshold breaches
├── grafana/
│   └── dashboard.json               # Importable Grafana dashboard
└── scripts/
    ├── kiosk.sh                     # Wall screen auto-start script
    └── kiosk.desktop                # Systemd autostart entry
```

---

## ESPHome configuration rules

- All three nodes use `esp32-c3-devkitm-1` board with Arduino framework
- I2C pins: `sda: GPIO6`, `scl: GPIO7` (ESP32-C3 Super Mini pinout)
- Status LED: `GPIO8`, inverted (active LOW on this board)
- WiFi credentials, API encryption key, and OTA password must use `!secret` references — never hardcode
- Each node includes a WiFi fallback AP for recovery
- Sensor update interval: `60s`
- Temperature offset of `-2.0°C` on all SCD40 nodes (self-heating compensation — user will fine-tune)
- SCD40 I2C address: `0x62`
- SGP40 on kitchen node requires `temperature_source` and `humidity_source` from the co-located SCD40 for humidity compensation

### Entity naming convention

Entity names must be consistent — InfluxDB and Grafana queries depend on them:

| Sensor | Entity ID format |
|---|---|
| CO₂ | `sensor.{room}_co2` |
| Temperature | `sensor.{room}_temperature` |
| Humidity | `sensor.{room}_humidity` |
| VOC index | `sensor.kitchen_voc_index` |

Where `{room}` is `bedroom`, `livingroom`, or `kitchen`.

---

## InfluxDB details

- **Version:** 2 (Flux query language — not InfluxQL)
- **Organization:** `home`
- **Bucket:** `air_quality`
- **Retention:** 365 days
- Home Assistant writes sensor data automatically via the InfluxDB integration
- The `configuration.yaml` InfluxDB section must use an `include` filter to limit writes to air quality sensors only (CO₂, temperature, humidity, VOC) — do not write all HA entities

### Flux query pattern

All Grafana panels use Flux. Reference pattern for a single sensor:

```flux
from(bucket: "air_quality")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "state")
  |> filter(fn: (r) => r.entity_id == "bedroom_co2")
  |> filter(fn: (r) => r._field == "value")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

---

## Grafana dashboard spec

The dashboard JSON (`grafana/dashboard.json`) should include these panels:

### Row 1 — CO₂ gauges (one per room)
- Panel type: Gauge
- Unit: `ppm`
- Thresholds:
  - Green: 0–800 ppm (good)
  - Yellow: 800–1000 ppm (elevated)
  - Red: 1000+ ppm (poor)
- Rooms: bedroom, living room, kitchen

### Row 2 — Temperature time series
- Panel type: Time series
- All three rooms on one graph, different colored lines
- Unit: `°F` (convert from Celsius in Flux: `|> map(fn: (r) => ({r with _value: r._value * 9.0 / 5.0 + 32.0}))`)
- Default time range: last 24 hours

### Row 3 — Humidity time series
- Panel type: Time series
- All three rooms on one graph
- Unit: `%`
- Reference bands: 30% (too dry) and 60% (too humid)

### Row 4 — VOC index gauge (kitchen only)
- Panel type: Gauge
- Unit: none (index value 0–500)
- Thresholds:
  - Green: 0–100 (normal)
  - Yellow: 100–150 (elevated)
  - Orange: 150–250 (high)
  - Red: 250+ (very high)

### Dashboard settings
- Theme: dark
- Refresh: every 60 seconds
- Default time range: last 6 hours
- Kiosk-friendly: no collapsed rows, panels fill screen

---

## Home Assistant automation rules

### Purifier control logic

- **Trigger:** VOC index on `sensor.kitchen_voc_index` rises above `150`
- **Action:** Turn on `switch.kitchen_purifier` (Sonoff S31 via Tasmota/MQTT)
- **Off trigger:** VOC falls below `80` for 10 minutes continuously
- **Action:** Turn off `switch.kitchen_purifier`

- **Trigger:** CO₂ in any room exceeds `1200 ppm`
- **Action:** Turn on `switch.living_room_purifier`
- **Off trigger:** All room CO₂ falls below `900 ppm` for 15 minutes
- **Action:** Turn off `switch.living_room_purifier`

### Alert notifications

- CO₂ above `1000 ppm` in any room → push notification via Home Assistant companion app
- CO₂ above `1500 ppm` in any room → urgent push notification
- Notifications should not repeat more than once per hour per room

---

## Secrets management

`esphome/secrets.yaml` is gitignored and must never be committed. It contains:

```yaml
wifi_ssid: "your_network_name"
wifi_password: "your_wifi_password"
api_encryption_key: "base64_key_here"  # Generate: openssl rand -base64 32
ota_password: "your_ota_password"
```

Users generate their own keys. The `secrets.yaml.example` file in the repo shows the required keys with placeholder values.

---

## Coding conventions

- YAML files: 2-space indentation
- All ESPHome configs must validate against ESPHome's schema
- Grafana dashboard JSON must be importable via Grafana's Import UI without modification
- Home Assistant automation YAML must use the modern trigger/action format (not legacy)
- Shell scripts: bash, with `set -euo pipefail` at the top
- No hardcoded IPs — use `raspberrypi.local` or note that users set their own static IP

---

## What has NOT been built yet

When starting work on this project, the following files need to be created:

- [ ] `esphome/bedroom-sensor.yaml`
- [ ] `esphome/livingroom-sensor.yaml`
- [ ] `esphome/kitchen-sensor.yaml`
- [ ] `esphome/secrets.yaml.example`
- [ ] `home-assistant/configuration.yaml`
- [ ] `home-assistant/automations/purifier-voc.yaml`
- [ ] `home-assistant/automations/purifier-co2.yaml`
- [ ] `home-assistant/automations/alerts.yaml`
- [ ] `grafana/dashboard.json`
- [ ] `scripts/kiosk.sh`
- [ ] `scripts/kiosk.desktop`
- [ ] `.gitignore` (must include `esphome/secrets.yaml`)
