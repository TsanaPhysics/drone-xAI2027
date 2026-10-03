import 'dart:typed_data';
import '../core/constants/drone_constants.dart';

class DronePacket {
  int roll; // 0..255 (128 center)
  int pitch; // 0..255 (128 center)
  int throttle; // 0..255 (0 min, 255 max)
  int yaw; // 0..255 (128 center)
  int commandFlag; // Takeoff (0x01), Land (0x02), Emergency (0x04)

  DronePacket({
    this.roll = DroneConstants.centerValue,
    this.pitch = DroneConstants.centerValue,
    this.throttle = DroneConstants.minByte,
    this.yaw = DroneConstants.centerValue,
    this.commandFlag = DroneConstants.cmdNormal,
  });

  /// Encodes into standard MAGIC 8-Byte UDP Packet
  /// [0x66, Roll, Pitch, Throttle, Yaw, Flags, Checksum, 0x99]
  Uint8List toBytes() {
    final int checksum = (roll ^ pitch ^ throttle ^ yaw ^ commandFlag) & 0xFF;
    return Uint8List.fromList([
      DroneConstants.packetHeader,
      roll & 0xFF,
      pitch & 0xFF,
      throttle & 0xFF,
      yaw & 0xFF,
      commandFlag & 0xFF,
      checksum,
      DroneConstants.packetFooter,
    ]);
  }

  String toHexString() {
    return toBytes()
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
