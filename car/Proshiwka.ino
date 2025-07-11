#include <WiFi.h>
#include <WiFiClient.h>
#include <WebServer.h>
#include <ArduinoJson.h>

const char* ap_ssid = "ESP32_AP";
const char* ap_password = "12345678";

WebServer server(80);

void handleRoot() {
    server.send(200, "text/plain", "ESP32");
}

void handleReceivePath() {
    if (server.method() == HTTP_POST) {
        String body = server.arg("plain");
        Serial.println("Получен JSON:");
        Serial.println(body);

        // Парсинг JSON
        StaticJsonDocument<1024> doc;
        DeserializationError error = deserializeJson(doc, body);

        if (error) {
            Serial.print("Ошибка парсинга JSON: ");
            Serial.println(error.c_str());
            server.send(400, "text/plain", "Ошибка формата JSON");
            return;
        }

        JsonArray path = doc["path"];
        for (JsonObject point : path) {
            int x = point["x"];
            int y = point["y"];
            Serial.printf("Координата: x=%d, y=%d\n", x, y);
        }

        server.send(200, "text/plain", "Данные получены успешно");
    } else {
        server.send(405, "text/plain", "Метод не поддерживается");
    }
}

void setup() {
    Serial.begin(115200);

    // Запуск точки доступа
    WiFi.softAP(ap_ssid, ap_password);
    IPAddress ip = WiFi.softAPIP();
    Serial.print("IP точки доступа: ");
    Serial.println(ip);

    // Роуты
    server.on("/", handleRoot);
    server.on("/receive-path", handleReceivePath);

    server.begin();
    Serial.println("HTTP сервер запущен");
}

void loop() {
    server.handleClient();
}
