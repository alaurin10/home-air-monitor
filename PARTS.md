# Parts List

Complete hardware reference for the `home-air-monitor` project. All prices in USD, approximate as of March 2026.

---

## System overview

```
3× ESP32 sensor nodes  ──WiFi──▶  Raspberry Pi 4 (Home Assistant + InfluxDB + Grafana)
                                         │                        │
                                   Wall screen              Your phone
                                  (always-on)           (via Tailscale VPN)

2× Sonoff S31 smart plugs  ◀──── Home Assistant automations
(air purifiers)
```

**Rooms with sensor nodes:** bedroom, living room, kitchen
**Kitchen node only:** adds SGP40 VOC sensor (cooking fumes detection)

---

## Sensor nodes (×3)

| Item | Detail | Qty | Est. cost |
|---|---|---|---|
| ESP32-C3 Super Mini | WiFi microcontroller. Buy from Waveshare, DIYmall, or Adafruit. Verify listing specifies **ESP32-C3FH4** chip or "4MB flash" — some no-name batches ship with no flash and don't work. | 3 | ~$18 |
| Adafruit SCD-40 breakout (STEMMA QT) | True photoacoustic CO₂ + temperature + humidity. STEMMA QT connectors mean no soldering. [Adafruit #5187](https://www.adafruit.com/product/5187) | 3 | ~$54 |
| Adafruit SGP40 breakout (STEMMA QT) | VOC index sensor. Kitchen node only. Chains to SCD40 via STEMMA QT. [Adafruit #4829](https://www.adafruit.com/product/4829) | 1 | ~$15 |
| STEMMA QT / Qwiic cables 100mm (×6) | Locking JST-SH cables connecting sensors to board. No soldering. Adafruit sells 4-packs. | 6 | ~$8 |
| Hammond 1591XXSSBK enclosures | Small matte black ABS project box (~85×56×35mm). One hole for USB-C, one small grille for airflow. Search "Hammond 1591XXSSBK" on Amazon or Digi-Key. | 3 | ~$15 |
| Right-angle USB-C cables 0.5m | Allows cable to hug the wall/shelf instead of sticking straight out. | 3 | ~$9 |
| Compact USB-A wall adapters | Flat-plug style (e.g. Anker Nano) so adapter is nearly flush with outlet. | 3 | ~$18 |

**Sensor node subtotal: ~$137**

---

## Raspberry Pi hub

| Item | Detail | Qty | Est. cost |
|---|---|---|---|
| Raspberry Pi 4 Model B (1GB) | Runs Home Assistant, InfluxDB, and Grafana simultaneously. 1GB is sufficient. The 1GB model held at $35 while higher-memory variants rose in early 2026 due to AI-driven memory shortages. | 1 | $35 |
| 32GB MicroSD card (Class 10 / A2) | A2-rated cards handle the random I/O of database writes better. Samsung PRO Endurance or SanDisk Endurance recommended. | 1 | ~$10 |
| Official Raspberry Pi USB-C power supply | Pi 4 needs a clean 5V/3A supply. The official one prevents SD card corruption from underpowering. | 1 | ~$12 |
| Argon ONE case *(optional)* | Aluminum enclosure that looks like a small media box — use if the Pi will ever be visible. Skip if it's fully hidden behind the screen. | 1 | ~$25 |

**Pi hub subtotal: ~$57 (without Argon ONE) / ~$82 (with)**

---

## Wall dashboard screen

| Item | Detail | Qty | Est. cost |
|---|---|---|---|
| 10.1" IPS HDMI touchscreen (1280×800) | Slim bezel, micro-HDMI input. Waveshare and Elecrow both make well-reviewed options. Search "10 inch HDMI raspberry pi touchscreen display". | 1 | ~$60 |
| Slim VESA wall mount bracket | Low-profile fixed-tilt mount (75×75mm). Keeps the screen flush to the wall. Many screens include a VESA adapter plate. | 1 | ~$10 |
| Micro-HDMI to HDMI cable 0.5m | Connects Pi to screen. Short length works when Pi is mounted behind the display. | 1 | ~$6 |

**Screen subtotal: ~$76**

---

## Smart plugs (air purifier control)

| Item | Detail | Qty | Est. cost |
|---|---|---|---|
| Sonoff S31 smart plugs | Flash with Tasmota firmware (one-time) for fully local control — no cloud, no app, no subscription. Works directly with Home Assistant via MQTT. See software guide for flashing instructions. | 2 | ~$20 |

**Smart plug subtotal: ~$20**

---

## Cable management

| Item | Detail | Qty | Est. cost |
|---|---|---|---|
| Cable raceway kit | Self-adhesive channels that run along baseboards to hide USB cables. Get white or black to match your walls. Paintable. Wiremold is a reliable brand. | 1 kit | ~$12 |
| 3M Command strips / adhesive mounts | For mounting enclosures to shelves or walls without screws. Damage-free removal — important for apartment use. | 1 pack | ~$6 |

**Cable management subtotal: ~$18**

---

## Grand total

| Section | Cost |
|---|---|
| Sensor nodes (×3) | ~$137 |
| Raspberry Pi hub | ~$57 |
| Wall dashboard screen | ~$76 |
| Smart plugs (×2) | ~$20 |
| Cable management | ~$18 |
| **Total** | **~$308** |
| + Argon ONE case (optional) | +$25 |

All software is free and open source. No ongoing subscription or hosting fees. Electricity cost to run the Pi is approximately $2–4/year.

---

## Sensors per node

| Node | SCD40 | SGP40 | Measures |
|---|---|---|---|
| Bedroom | ✓ | — | CO₂, temperature, humidity |
| Living room | ✓ | — | CO₂, temperature, humidity |
| Kitchen | ✓ | ✓ | CO₂, temperature, humidity, VOC index |

---

## Buying notes

- **ESP32-C3 Super Mini:** Recent batches from reputable sellers have been reliable. Avoid random Amazon marketplace sellers — buy from Waveshare, DIYmall, Adafruit, or similar. The key thing to confirm is that the listing specifies 4MB flash (chip marking `ESP32-C3FH4`).
- **Raspberry Pi:** Buy from an approved reseller listed at raspberrypi.com. Prices fluctuated in late 2025 / early 2026 due to memory shortages — verify current pricing before ordering.
- **Sonoff S31:** Available on Amazon or directly from itead.cc. Either works — the firmware gets replaced anyway.
- **Enclosures:** Hammond Manufacturing boxes are available on Amazon, Digi-Key, and Mouser. The 1591XXSSBK is the right size for an ESP32-C3 Super Mini + SCD40.
