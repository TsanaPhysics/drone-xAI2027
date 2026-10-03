/// Constants & Protocol Specs for MAGIC / KY Toy WiFi Drones
library;

class DroneConstants {
  // Default WiFi Network Configuration for Magic Drone
  static const String defaultDroneIp = '192.168.1.1';
  static const int defaultControlPort = 7070; // Common for KY / Magic Speed
  static const int fallbackControlPort = 8080;
  static const int defaultStreamPort = 8080;
  static const String defaultStreamPath = '/?action=stream';

  // Packet Delimiters
  static const int packetHeader = 0x66;
  static const int packetFooter = 0x99;

  // Command Flags (Byte 5)
  static const int cmdNormal = 0x00;
  static const int cmdTakeoff = 0x01;
  static const int cmdLand = 0x02;
  static const int cmdEmergency = 0x04;
  static const int cmdFlip = 0x08;
  static const int cmdCalibrate = 0x10;

  // Control Range
  static const int centerValue = 128; // 0x80
  static const int maxByte = 255;
  static const int minByte = 0;

  // Heartbeat Rate
  static const Duration heartbeatInterval = Duration(milliseconds: 50); // 20 Hz
}
