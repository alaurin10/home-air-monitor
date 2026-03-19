# Air Quality Monitor — Software Setup Guide

A step-by-step guide to setting up the full software stack for a multi-room air quality monitoring system with a local dashboard and remote access. No cloud subscriptions required.

---

## Stack overview

```
[ESP32 sensor nodes]  →  [Home Assistant + ESPHome]  →  [InfluxDB]  →  [Grafana]
      WiFi                    Raspberry Pi                time-series      dashboard
                                                          database       (wall + phone)

Remote access via Tailscale (free, personal use)
```

**Software used:**

| Software | Role | Cost |
|---|---|---|
| Raspberry Pi OS Lite | Operating system for the Pi | Free |
| ESPHome | Firmware for ESP32 sensor nodes | Free |
| Home Assistant | Automation engine, sensor hub, smart plug control | Free |
| InfluxDB v2 | Time-series database for storing sensor data | Free |
| Grafana | Dashboard and visualization | Free |
| Tailscale | Secure remote access (no port forwarding) | Free (personal) |

---

## Phase 1 — Raspberry Pi initial setup

### 1.1 Flash the SD card

1. Download **Raspberry Pi Imager** on your laptop: https://www.raspberrypi.com/software/
2. Insert the 32GB microSD card
3. In the Imager, choose:
   - **OS:** Raspberry Pi OS Lite (64-bit) — no desktop needed, saves RAM
   - **Storage:** your SD card
4. Click the gear icon (⚙) before flashing and configure:
   - Enable SSH
   - Set a username and password (e.g., `pi` / something strong)
   - Set your WiFi network name and password
   - Set your timezone to `America/Los_Angeles`
5. Flash the card, insert it into the Pi, and power it on

### 1.2 Find the Pi on your network

From your laptop (on the same WiFi):

```bash
ping raspberrypi.local
```

If that doesn't resolve, check your router's admin page for a device named `raspberrypi` and use its IP address directly.

### 1.3 SSH into the Pi

```bash
ssh pi@raspberrypi.local
```

### 1.4 Update the system

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

SSH back in after the reboot.

### 1.5 Give the Pi a static local IP

This ensures Home Assistant, Grafana, and Tailscale always resolve to the same address.

```bash
sudo nano /etc/dhcpcd.conf
```

Add at the bottom (replace `192.168.1.100` with a free IP on your network, and `192.168.1.1` with your router's IP):

```
interface wlan0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

Save (`Ctrl+X`, `Y`, `Enter`) and reboot:

```bash
sudo reboot
```

---

## Phase 2 — Home Assistant

Home Assistant is the central hub. It receives sensor data from ESPHome nodes, controls smart plugs, and forwards data to InfluxDB.

### 2.1 Install Home Assistant Supervised

The recommended install method for a Pi running Raspberry Pi OS is **Home Assistant Supervised**. It gives you the full Home Assistant experience (including add-ons like ESPHome) without needing the dedicated Home Assistant OS.

Install dependencies:

```bash
sudo apt install -y \
  apparmor \
  cifs-utils \
  curl \
  dbus \
  jq \
  libglib2.0-bin \
  lsb-release \
  network-manager \
  nfs-common \
  systemd-journal-remote \
  systemd-resolved \
  udisks2 \
  wget

sudo reboot
```

Install Docker:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker pi
```

Install the Home Assistant Supervised installer:

```bash
wget -O homeassistant-supervised.deb \
  https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb

sudo apt install -y ./homeassistant-supervised.deb
```

When prompted, select **Raspberry Pi 4** as the machine type.

> **Note:** Installation takes 10–20 minutes. Home Assistant downloads and starts several Docker containers.

### 2.2 Access Home Assistant

On any browser on your network:

```
http://192.168.1.100:8123
```

Complete the onboarding wizard — create a user account, set your location.

### 2.3 Install the ESPHome add-on

In Home Assistant:

1. Go to **Settings → Add-ons → Add-on Store**
2. Search for **ESPHome**
3. Install it, then enable **Start on boot** and **Show in sidebar**
4. Start the add-on

ESPHome will now be accessible directly from your Home Assistant sidebar.

---

## Phase 3 — ESPHome sensor node firmware

ESPHome lets you configure your ESP32 nodes using a simple YAML file. No writing raw Arduino code required.

### 3.1 Create a node configuration

In the ESPHome dashboard (Home Assistant sidebar → ESPHome):

1. Click **New Device**
2. Name it (e.g., `bedroom-sensor`)
3. Select **ESP32-C3**
4. ESPHome generates a base YAML config — you'll edit this

### 3.2 Node YAML configuration

This is the configuration for a full sensor node with SCD40 (CO₂ + temperature + humidity). When you set up your GitHub project, Claude Code will generate these files for you — this is the reference structure:

```yaml
# bedroom-sensor.yaml
esphome:
  name: bedroom-sensor
  friendly_name: Bedroom Sensor

esp32:
  board: esp32-c3-devkitm-1
  framework:
    type: arduino

# WiFi credentials — use Home Assistant secrets
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:  # Fallback hotspot if WiFi fails
    ssid: "Bedroom Sensor Fallback"
    password: "fallback123"

# Enable Home Assistant API
api:
  encryption:
    key: !secret api_encryption_key

# Enable OTA updates (update firmware wirelessly)
ota:
  password: !secret ota_password

# Enable logging
logger:

# I2C bus (SDA and SCL pins for ESP32-C3 Super Mini)
i2c:
  sda: GPIO6
  scl: GPIO7
  scan: true

# SCD40 — CO₂, temperature, humidity
sensor:
  - platform: scd4x
    co2:
      name: "Bedroom CO2"
      id: bedroom_co2
    temperature:
      name: "Bedroom Temperature"
      id: bedroom_temp
      filters:
        - offset: -2.0  # Calibration offset — adjust after testing
    humidity:
      name: "Bedroom Humidity"
      id: bedroom_humidity
    address: 0x62
    update_interval: 60s  # Measure every 60 seconds

# Status LED (optional, onboard blue LED on ESP32-C3)
light:
  - platform: status_led
    name: "Status LED"
    pin:
      number: GPIO8
      inverted: true
```

For the **kitchen node** with an additional SGP40 VOC sensor, add:

```yaml
  - platform: sgp4x
    voc:
      name: "Kitchen VOC Index"
    compensation:
      temperature_source: kitchen_temp
      humidity_source: kitchen_humidity
    update_interval: 60s
```

### 3.3 Flash the first node

1. Connect the ESP32-C3 to your laptop via USB-C
2. In ESPHome dashboard, click your device → **Install → Plug into this computer**
3. ESPHome compiles the firmware and flashes it
4. After the first flash, all future updates happen over WiFi (OTA)

### 3.4 Verify in Home Assistant

After flashing, the node should appear in **Settings → Devices & Services** as a new ESPHome device. You'll see all sensors listed and can check that readings look correct.

---

## Phase 4 — InfluxDB

InfluxDB stores all your sensor readings as a time-series database. This is what makes historical graphs and trends possible.

### 4.1 Install InfluxDB v2

```bash
# Add the InfluxDB repository
curl https://repos.influxdata.com/influxdata-archive.key | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/influxdb-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/influxdb-archive-keyring.gpg] \
  https://repos.influxdata.com/debian stable main" | \
  sudo tee /etc/apt/sources.list.d/influxdb.list

sudo apt update && sudo apt install -y influxdb2

# Start and enable on boot
sudo systemctl enable influxdb
sudo systemctl start influxdb
```

### 4.2 Initial InfluxDB setup

Open a browser and go to `http://192.168.1.100:8086`

Complete the setup wizard:
- **Username:** admin (or your choice)
- **Password:** something strong
- **Organization:** home (or your name)
- **Bucket:** `air_quality`
- **Retention:** 365 days (or longer — Pi storage is the only limit)

After setup, go to **Load Data → API Tokens** and create a new token with **All Access** permissions. Save this token — you'll need it for Home Assistant and Grafana.

### 4.3 Connect Home Assistant to InfluxDB

In Home Assistant, go to **Settings → Integrations → Add Integration** and search for **InfluxDB**.

Configure it:
- **Host:** `localhost` (or `127.0.0.1`)
- **Port:** `8086`
- **API Token:** (paste your token)
- **Organization:** `home`
- **Bucket:** `air_quality`
- **Version:** 2

Home Assistant will now write every sensor reading to InfluxDB automatically.

> **Tip:** By default, Home Assistant writes ALL entities to InfluxDB. To limit it to just your air quality sensors, add an `include` filter in `configuration.yaml`. Claude Code can generate this filter for you when you set up the project.

---

## Phase 5 — Grafana

Grafana reads from InfluxDB and renders your dashboard — the same view appears on the wall screen and on your phone.

### 5.1 Install Grafana

```bash
# Add Grafana repository
sudo mkdir -p /etc/apt/keyrings
curl https://apt.grafana.com/gpg.key | \
  gpg --dearmor | \
  sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] \
  https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update && sudo apt install -y grafana

# Start and enable on boot
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

### 5.2 Access Grafana

In a browser: `http://192.168.1.100:3000`

Default login: `admin` / `admin` — you'll be prompted to change the password.

### 5.3 Add InfluxDB as a data source

1. Go to **Connections → Data Sources → Add data source**
2. Select **InfluxDB**
3. Configure:
   - **Query Language:** Flux
   - **URL:** `http://localhost:8086`
   - **Organization:** `home`
   - **Token:** (paste your InfluxDB API token)
   - **Default Bucket:** `air_quality`
4. Click **Save & Test** — should show "datasource is working"

### 5.4 Build your dashboard

The project includes three importable dashboard JSON files in `grafana/`:

| File | UID | Purpose |
|---|---|---|
| `wall-dashboard.json` | `air-quality-wall` | **Wall screen** — all sensors as real-time gauges with colored scales |
| `history-dashboard.json` | `air-quality-history` | **Phone** — time-series history graphs for all sensors, default last 24h |
| `dashboard.json` | `air-quality-monitor` | Combined view (gauges + graphs) — optional fallback |

**Import each dashboard:**

1. Go to **Dashboards → Import**
2. Upload the JSON file (or paste its contents)
3. When prompted, select your InfluxDB data source
4. Click **Import**

Repeat for each of the three files. You only need `wall-dashboard.json` and `history-dashboard.json` for day-to-day use.

### 5.5 Set Grafana to kiosk mode for the wall screen

Kiosk mode hides the Grafana navigation bars for a clean full-screen look on the wall display.

The wall screen uses the `air-quality-wall` dashboard. Its kiosk URL is:

```
http://localhost:3000/d/air-quality-wall/air-quality-wall?kiosk&theme=dark
```

The `scripts/kiosk.sh` file in this project is pre-configured with this URL and launches automatically on boot (see Phase 8).

---

## Phase 6 — Smart plug automation

With Home Assistant, you can automate air purifier control based on sensor readings.

### 6.1 Flash Tasmota on the Sonoff S31 plugs

Tasmota is open-source firmware that makes the Sonoff plugs work fully locally — no cloud, no app required.

1. Download **Tasmotizer**: https://github.com/tasmota/tasmotizer
2. Connect the Sonoff S31 to your laptop (requires a USB-TTL adapter the first time, or use Tasmota's web installer if your Sonoff ships with compatible firmware)
3. Flash `tasmota.bin`
4. Connect the plug to your WiFi via the Tasmota web interface
5. In Tasmota, go to **Configuration → MQTT** and point it to Home Assistant's built-in MQTT broker

After this, the plugs appear automatically in Home Assistant.

> **Easier alternative:** If flashing feels like too much at first, the Sonoff S31 can also work via its stock eWeLink cloud. You can add the eWeLink integration to Home Assistant and automate it that way — then flash Tasmota later when you're comfortable.

### 6.2 Create automations in Home Assistant

Go to **Settings → Automations → Create Automation**. Example logic:

**Purifier on when VOC is high (kitchen):**
- Trigger: `sensor.kitchen_voc_index` rises above `150`
- Action: Turn on `switch.kitchen_purifier`

**Purifier off when VOC returns to normal:**
- Trigger: `sensor.kitchen_voc_index` falls below `80`
- Delay: 10 minutes (to avoid rapid on/off cycling)
- Action: Turn off `switch.kitchen_purifier`

**CO₂ alert notification:**
- Trigger: `sensor.bedroom_co2` rises above `1000` ppm
- Action: Send a notification to your phone (via the Home Assistant companion app)

When you set up the GitHub project, Claude Code will generate the full YAML automation files.

---

## Phase 7 — Remote access with Tailscale

Tailscale creates a secure private network between your Pi and your phone. The Grafana dashboard becomes accessible from anywhere without opening ports in your router.

### 7.1 Install Tailscale on the Pi

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

A URL will appear in the terminal — open it on your phone to authenticate.

### 7.2 Install Tailscale on your phone

Install the Tailscale app (iOS or Android) and sign into the same account.

### 7.3 Access Grafana remotely

After both devices are connected, your Pi gets a stable Tailscale IP (e.g., `100.x.x.x`). Use the **history dashboard** on your phone to browse past readings:

```
http://100.x.x.x:3000/d/air-quality-history
```

Save this as a home screen shortcut on your phone for one-tap access. Use the Grafana time picker in the top-right to switch between last 24h, 7 days, 30 days, etc.

> **Privacy note:** Your sensor data never leaves your home network. Tailscale only coordinates the encrypted tunnel — it does not see or store your data.

---

## Phase 8 — Wall screen auto-start

The wall screen should show the Grafana dashboard automatically on boot, with no mouse or keyboard needed.

### 8.1 Install a minimal display stack on the Pi

```bash
sudo apt install -y \
  xorg \
  chromium-browser \
  unclutter  # Hides the mouse cursor after inactivity
```

### 8.2 Deploy the auto-start script

The project includes pre-built `scripts/kiosk.sh` and `scripts/kiosk.desktop`. Copy them to the Pi:

```bash
cp scripts/kiosk.sh ~/kiosk.sh
chmod +x ~/kiosk.sh
```

`kiosk.sh` is pre-configured to open the wall dashboard (`air-quality-wall`) in full-screen kiosk mode. It waits 30 seconds for Grafana to start, disables screen blanking, and hides the cursor.

### 8.3 Run on boot

```bash
mkdir -p ~/.config/autostart
cp scripts/kiosk.desktop ~/.config/autostart/kiosk.desktop
```

Reboot — the wall dashboard should open automatically on the screen.

---

## GitHub project structure (for Claude Code)

When you create the GitHub project, structure it like this. Claude Code will populate each file:

```
air-quality-monitor/
├── README.md
├── esphome/
│   ├── secrets.yaml          # WiFi/API keys (gitignored)
│   ├── bedroom-sensor.yaml
│   ├── livingroom-sensor.yaml
│   └── kitchen-sensor.yaml   # Includes SGP40 VOC config
├── home-assistant/
│   ├── configuration.yaml    # InfluxDB include filter
│   └── automations/
│       ├── purifier-control.yaml
│       └── co2-alerts.yaml
├── grafana/
│   ├── wall-dashboard.json   # Wall screen — real-time gauges
│   ├── history-dashboard.json # Phone — historical time-series graphs
│   └── dashboard.json        # Combined fallback dashboard
└── scripts/
    └── kiosk.sh              # Wall screen auto-start
```

### What to ask Claude Code to generate

When you open the project in Claude Code, use these prompts as a starting point:

1. `"Generate ESPHome YAML configs for three sensor nodes: bedroom (SCD40), living room (SCD40), and kitchen (SCD40 + SGP40). Use secrets for WiFi credentials."`

2. `"Generate a Home Assistant configuration.yaml InfluxDB section that only includes sensors matching 'co2', 'temperature', 'humidity', and 'voc' in their entity IDs."`

3. `"Generate Home Assistant automation YAML for: turning on a smart plug when VOC index exceeds 150, turning it off after 10 minutes below 80, and sending a phone notification when CO₂ exceeds 1000ppm in any room."`

4. `"Generate a Grafana dashboard JSON with: a CO₂ gauge per room (green/yellow/red thresholds), a multi-line temperature graph, a multi-line humidity graph, and a VOC gauge for the kitchen. Data source is InfluxDB v2 using Flux query language, bucket 'air_quality'."`

---

## Phase 9 — Additional features

### 9.1 Sensor offline detection

**Files:** `home-assistant/automations/sensor-health.yaml`

No extra setup needed. Import the automation file in HA (**Settings → Automations → ⋮ → Import**). Each node sends a push notification if it stops reporting for 5 minutes.

To test: unplug a sensor node, wait 5 minutes, check for notification.

---

### 9.2 CO₂ rapid-rise alerts

**Files:** `home-assistant/automations/rapid-rise-alerts.yaml`, `home-assistant/configuration.yaml`

The `derivative:` sensors in `configuration.yaml` must be active before the automations will work.

1. Copy the updated `configuration.yaml` to your Pi (merge with existing if needed)
2. Restart Home Assistant (**Settings → System → Restart**)
3. Wait 2–3 minutes, then check **Settings → Developer Tools → States** and search for `co2_rate` — you should see three derivative sensors with values
4. Import `rapid-rise-alerts.yaml`

Alert triggers when CO₂ rises faster than 20 ppm/min. Adjust the threshold in the automation if too noisy.

---

### 9.3 Wall screen night mode

**Files:** `home-assistant/automations/night-mode.yaml`, `home-assistant/configuration.yaml`

The `shell_command:` block in `configuration.yaml` must be active. HA uses `vcgencmd` to control the HDMI output — this requires the HA process user to be in the `video` group on the Pi:

```bash
sudo usermod -aG video pi
sudo reboot
```

After rebooting, reload the HA configuration, then import `night-mode.yaml`. The screen will turn off at 23:00 and back on at 07:00. Edit the times in the automation to match your schedule.

To test manually: **Settings → Developer Tools → Services → shell_command.screen_off → Call Service**.

---

### 9.4 Sonoff S31 power monitoring

**Files:** `home-assistant/configuration.yaml`, `grafana/history-dashboard.json`

Tasmota automatically exposes wattage as MQTT sensors. After Tasmota is set up (Phase 6.1), the S31 power entities should auto-appear in HA. Verify the exact entity IDs:

1. In HA, go to **Settings → Devices & Services → Entities**
2. Search for your plug's device name — you'll see entities like `sensor.{name}_power`
3. If the names differ from `sensor.kitchen_purifier_power` / `sensor.living_room_purifier_power`, update the Flux queries in `history-dashboard.json` accordingly

The updated `configuration.yaml` already includes `sensor.*_power` in the InfluxDB include filter, so data will flow automatically once HA restarts.

---

### 9.5 Outdoor air quality

**Files:** `home-assistant/configuration.yaml`, `grafana/wall-dashboard.json`

Requires a free OpenWeatherMap API key:

1. Sign up at [openweathermap.org](https://openweathermap.org/api) — the free tier is sufficient
2. In HA, go to **Settings → Integrations → Add Integration → OpenWeatherMap**
3. Enter your API key, set your location
4. HA will create entities including `sensor.openweathermap_air_quality_index`
5. Re-import `wall-dashboard.json` — the Outdoor AQI gauge will populate automatically

The AQI scale is 1–5 (EU standard): 1 = Good, 2 = Fair, 3 = Moderate, 4 = Poor, 5 = Very Poor.

---

### 9.6 Daily summary notification

**Files:** `home-assistant/automations/daily-summary.yaml`, `home-assistant/configuration.yaml`

Requires the `statistics:` and `history_stats:` sensors in `configuration.yaml` to be active (same restart as step 9.2). After HA restarts, import `daily-summary.yaml`. A notification will arrive at 08:00 each morning with yesterday's peak CO₂ and purifier runtime.

To test immediately: **Settings → Automations → Daily Air Quality Summary → ⋮ → Run**.

---

## Calibration tips

After everything is running, give the sensors 24–48 hours to stabilize before trusting the readings.

**Temperature offset:** The SCD40 runs slightly warm due to self-heating. The config above includes a `-2.0°C` offset — adjust this per node by comparing against a known-good thermometer.

**CO₂ baseline:** The SCD40 self-calibrates over time assuming it sees fresh outdoor air (~415 ppm) at least once every few days. Opening a window periodically speeds this up. ESPHome's `scd4x` component handles this automatically.

**VOC index:** The SGP40 VOC index is relative, not absolute — it learns your baseline over the first hour of operation and reports deviations from that baseline. A value of 100 is normal; above 150 is elevated.

---

## Troubleshooting quick reference

| Problem | Check |
|---|---|
| Sensor node not appearing in HA | ESPHome logs → check WiFi credentials, verify the API encryption key matches |
| InfluxDB showing no data | Home Assistant → Settings → Integrations → InfluxDB → check for errors |
| Grafana "No data" on panels | Verify Flux query bucket name matches exactly. Use Grafana's query inspector. |
| Wall screen blank on boot | Check `~/.config/autostart/kiosk.desktop`, verify Grafana is running (`systemctl status grafana-server`) |
| Can't reach Grafana via Tailscale | Ensure both Pi and phone show "Connected" in Tailscale app |
| CO₂ readings seem high | Normal — apartments with little ventilation often run 800–1200ppm. Open a window and watch it drop. |
