#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>

const uint8_t SOIL_PIN = 34;
const uint8_t RELAY_PIN = 27;
const uint8_t RELAY_ON = LOW;
const uint8_t RELAY_OFF = HIGH;

const int DRY_READING = 3000;
const int WET_READING = 1300;
const uint8_t WATER_BELOW_PERCENT = 35;
const unsigned long SAMPLE_INTERVAL_MS = 2000UL;
const unsigned long MAX_WATER_TIME_MS = 8000UL;
const unsigned long WATER_COOLDOWN_MS = 60000UL;

WebServer server(80);
bool automaticMode = true;
bool pumpRunning = false;
int moisturePercent = 0;
int rawReading = 0;
unsigned long pumpStartedAt = 0;
unsigned long lastWaterFinishedAt = 0;
unsigned long lastSampleAt = 0;

int readMoisturePercent() {
  long total = 0;
  for (uint8_t i = 0; i < 10; ++i) {
    total += analogRead(SOIL_PIN);
    delay(3);
  }
  rawReading = total / 10;
  return constrain(map(rawReading, DRY_READING, WET_READING, 0, 100), 0, 100);
}

void startPump() {
  if (pumpRunning) return;
  digitalWrite(RELAY_PIN, RELAY_ON);
  pumpRunning = true;
  pumpStartedAt = millis();
}

void stopPump() {
  digitalWrite(RELAY_PIN, RELAY_OFF);
  pumpRunning = false;
  lastWaterFinishedAt = millis();
}

void handleRoot() {
  String page = F("<!doctype html><html><meta name='viewport' content='width=device-width,initial-scale=1'><title>Plant Watering</title><style>body{font-family:Arial;background:#eef7ee;color:#173b20;margin:24px}.card{background:white;max-width:420px;padding:22px;border-radius:14px;box-shadow:0 2px 10px #b8cbb8}button{padding:12px;margin:5px;border:0;border-radius:8px;background:#287a3d;color:white;font-size:16px}.off{background:#a33}</style><body><div class='card'><h1>Plant Watering</h1><p><b>Soil moisture:</b> ");
  page += moisturePercent;
  page += F("%</p><p><b>Raw reading:</b> ");
  page += rawReading;
  page += F("</p><p><b>Pump:</b> ");
  page += pumpRunning ? F("ON") : F("OFF");
  page += F("</p><p><b>Automatic watering:</b> ");
  page += automaticMode ? F("ON") : F("OFF");
  page += F("</p><a href='/pump/on'><button>Water now</button></a><a href='/pump/off'><button class='off'>Stop pump</button></a><a href='/auto'><button>Toggle automatic mode</button></a><p>Refresh this page for the newest reading.</p></div></body></html>");
  server.send(200, "text/html", page);
}

// JSON status used by the Flutter app.
void sendStatusJson() {
  const unsigned long now = millis();
  unsigned long pumpRemainingMs = 0;
  if (pumpRunning) {
    const unsigned long elapsed = now - pumpStartedAt;
    pumpRemainingMs = elapsed < MAX_WATER_TIME_MS ? MAX_WATER_TIME_MS - elapsed : 0;
  }
  unsigned long cooldownRemainingMs = 0;
  if (!pumpRunning && lastWaterFinishedAt != 0) {
    const unsigned long since = now - lastWaterFinishedAt;
    cooldownRemainingMs = since < WATER_COOLDOWN_MS ? WATER_COOLDOWN_MS - since : 0;
  }

  String json = F("{\"moisture\":");
  json += moisturePercent;
  json += F(",\"raw\":");
  json += rawReading;
  json += F(",\"pump\":");
  json += pumpRunning ? F("true") : F("false");
  json += F(",\"auto\":");
  json += automaticMode ? F("true") : F("false");
  json += F(",\"threshold\":");
  json += WATER_BELOW_PERCENT;
  json += F(",\"pumpRemainingMs\":");
  json += pumpRemainingMs;
  json += F(",\"cooldownRemainingMs\":");
  json += cooldownRemainingMs;
  json += F(",\"uptimeMs\":");
  json += now;
  json += F("}");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void setup() {
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);
  analogReadResolution(12);
  Serial.begin(115200);
  WiFi.softAP("Plant-Watering", "WaterPlant2026");

  // Browser page
  server.on("/", handleRoot);
  server.on("/pump/on", [](){ startPump(); server.sendHeader("Location", "/"); server.send(303); });
  server.on("/pump/off", [](){ stopPump(); server.sendHeader("Location", "/"); server.send(303); });
  server.on("/auto", [](){ automaticMode = !automaticMode; server.sendHeader("Location", "/"); server.send(303); });

  // JSON API for the Flutter app
  server.on("/api/status", HTTP_GET, sendStatusJson);
  server.on("/api/pump/on", HTTP_POST, [](){ startPump(); sendStatusJson(); });
  server.on("/api/pump/off", HTTP_POST, [](){ stopPump(); sendStatusJson(); });
  server.on("/api/auto", HTTP_POST, [](){
    if (server.hasArg("enabled")) automaticMode = server.arg("enabled") == "1";
    else automaticMode = !automaticMode;
    sendStatusJson();
  });

  server.begin();
  Serial.println("Connect phone to Plant-Watering and open http://192.168.4.1");
}

void loop() {
  server.handleClient();
  const unsigned long now = millis();
  if (pumpRunning && now - pumpStartedAt >= MAX_WATER_TIME_MS) stopPump();
  if (now - lastSampleAt >= SAMPLE_INTERVAL_MS) {
    lastSampleAt = now;
    moisturePercent = readMoisturePercent();
    if (automaticMode && !pumpRunning && now - lastWaterFinishedAt >= WATER_COOLDOWN_MS && moisturePercent < WATER_BELOW_PERCENT) startPump();
  }
}
