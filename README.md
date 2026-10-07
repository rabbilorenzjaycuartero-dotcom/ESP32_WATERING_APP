# ESP32_WATERING_APP

Automatic plant watering with an ESP32, a soil moisture sensor and a relay-driven pump, controlled from a Flutter phone app.

## Project layout

- `firmware/plant_watering/` – ESP32 Arduino sketch
- `plant_watering_app/` – Flutter app (Android / iOS)

## Hardware

| Part | ESP32 pin |
| --- | --- |
| Soil moisture sensor (analog out) | GPIO 34 |
| Relay (pump) | GPIO 27 (active LOW) |

Calibrate `DRY_READING` and `WET_READING` in the sketch for your sensor.

## Firmware

Upload `firmware/plant_watering/plant_watering.ino` with the Arduino IDE (ESP32 board package).
The ESP32 starts a Wi-Fi access point:

- SSID: `Plant-Watering`
- Password: `WaterPlant2026`
- Address: `http://192.168.4.1`

Automatic mode waters for up to 8 s when moisture drops below 35%, then waits 60 s before watering again.

### JSON API

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/status` | Moisture, raw reading, pump and auto state |
| POST | `/api/pump/on` | Start the pump |
| POST | `/api/pump/off` | Stop the pump |
| POST | `/api/auto?enabled=1` or `0` | Turn automatic watering on or off |

## Flutter app

```
cd plant_watering_app
flutter run
```

1. Connect the phone to the `Plant-Watering` Wi-Fi.
2. Turn off mobile data if the app says it cannot reach the ESP32 (Android may route traffic over mobile data because the access point has no internet).
3. Open the app. Use the flask icon for **demo mode** to try it without the ESP32.
