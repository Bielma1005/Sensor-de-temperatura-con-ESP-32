#include "WiFi.h"
#include "ESPAsyncWebServer.h"
#include <Adafruit_Sensor.h>
#include <DHT.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

// Replace with your network credentials
const char* ssid = "LAB ELECTRONICA E IA"; 
const char* password = "Electro2024.#.";

#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// OLED display width and height
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// Buzzer pin and temperature threshold
#define BUZZER_PIN 14
#define TEMP_THRESHOLD_HIGH 30.0 // High temperature threshold in °C
#define TEMP_THRESHOLD_LOW 20.0  // Low temperature threshold in °C

// LED RGB pins
#define LED_RED_PIN 25
#define LED_GREEN_PIN 26
#define LED_BLUE_PIN 27

// Create AsyncWebServer object on port 80
AsyncWebServer server(80);

String readDHTTemperature() {
  float t = dht.readTemperature();
  if (isnan(t)) {
    Serial.println("Failed to read from DHT sensor!");
    return "--";
  } else {
    return String(t);
  }
}

String readDHTHumidity() {
  float h = dht.readHumidity();
  if (isnan(h)) {
    Serial.println("Failed to read from DHT sensor!");
    return "--";
  } else {
    return String(h);
  }
}

const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE HTML><html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html { font-family: Arial; text-align: center; margin: 0 auto; }
    h2 { font-size: 2rem; }
    p { font-size: 1.5rem; }
  </style>
</head>
<body>
  <h2>ESP32 DHT Server</h2>
  <p>Temperature: <span id="temperature">%TEMPERATURE%</span>&deg;C</p>
  <p>Humidity: <span id="humidity">%HUMIDITY%</span>&percnt;</p>
</body>
<script>
setInterval(function() {
  fetch("/temperature").then(response => response.text()).then(data => {
    document.getElementById("temperature").innerHTML = data;
  });
  fetch("/humidity").then(response => response.text()).then(data => {
    document.getElementById("humidity").innerHTML = data;
  });
}, 1000);
</script>
</html>)rawliteral";

// Replaces placeholder with DHT values
String processor(const String& var) {
  if (var == "TEMPERATURE") {
    return readDHTTemperature();
  } else if (var == "HUMIDITY") {
    return readDHTHumidity();
  }
  return String();
}

void setup() {
  Serial.begin(115200);
  dht.begin();

  // Initialize buzzer pin
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize LED RGB pins
  pinMode(LED_RED_PIN, OUTPUT);
  pinMode(LED_GREEN_PIN, OUTPUT);
  pinMode(LED_BLUE_PIN, OUTPUT);
  digitalWrite(LED_RED_PIN, LOW);
  digitalWrite(LED_GREEN_PIN, LOW);
  digitalWrite(LED_BLUE_PIN, LOW);

  // Initialize OLED display
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("SSD1306 allocation failed");
    for (;;);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected! IP address:");
  Serial.println(WiFi.localIP());

  // Setup web server routes
  server.on("/", HTTP_GET, [](AsyncWebServerRequest * request) {
    request->send_P(200, "text/html", index_html, processor);
  });
  server.on("/temperature", HTTP_GET, [](AsyncWebServerRequest * request) {
    request->send_P(200, "text/plain", readDHTTemperature().c_str());
  });
  server.on("/humidity", HTTP_GET, [](AsyncWebServerRequest * request) {
    request->send_P(200, "text/plain", readDHTHumidity().c_str());
  });

  // Start server
  server.begin();
}

void setRGBColor(bool red, bool green, bool blue) {
  digitalWrite(LED_RED_PIN, red ? HIGH : LOW);
  digitalWrite(LED_GREEN_PIN, green ? HIGH : LOW);
  digitalWrite(LED_BLUE_PIN, blue ? HIGH : LOW);
}

void loop() {
  // Read temperature and humidity
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  // Update OLED display
  display.clearDisplay();
  display.setCursor(0, 0);
  display.print("Temperature: ");
  display.print(temperature);
  display.println(" C");
  display.print("Humidity: ");
  display.print(humidity);
  display.println(" %");
  display.display();

  // Check temperature and set RGB LED
  if (temperature > TEMP_THRESHOLD_HIGH) {
    setRGBColor(true, false, false); // Red for high temperature
  } else if (temperature < TEMP_THRESHOLD_LOW) {
    setRGBColor(false, false, true); // Blue for low temperature
  } else {
    setRGBColor(false, true, false); // Green for normal temperature
  }

  // Activate buzzer if temperature exceeds high threshold
  if (temperature > TEMP_THRESHOLD_HIGH) {
    digitalWrite(BUZZER_PIN, HIGH); // Turn buzzer on
    delay(500);
    digitalWrite(BUZZER_PIN, LOW);  // Turn buzzer off
  }

  delay(1000); // Update every 1 second
}
