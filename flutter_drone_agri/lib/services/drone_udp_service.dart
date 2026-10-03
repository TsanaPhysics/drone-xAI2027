import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants/drone_constants.dart';
import '../models/drone_packet.dart';
import '../models/flight_waypoint.dart';

class DroneUdpService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _telemetrySimTimer;

  String _droneIp = DroneConstants.defaultDroneIp;
  int _dronePort = DroneConstants.defaultControlPort;

  bool _isConnected = false;
  bool _isFlying = false;
  String _statusMessage = 'พร้อมเชื่อมต่อ (Ready)';
  
  final DronePacket _currentPacket = DronePacket();
  int _trimPitch = 0;
  int _trimRoll = 0;

  // Real-time Flight Telemetry State
  double _altitude = 0.0; // เมตร
  double _speed = 0.0;    // m/s
  int _batteryPercent = 95; // %
  double _headingDegrees = 0.0; // 0..360 deg
  double _pitchAngle = 0.0; // deg
  double _rollAngle = 0.0;  // deg
  final double _windSpeedMps = 2.4; // ความเร็วลม (m/s)
  
  // Precision Spraying State
  bool _isSprayActive = false;
  double _sprayPwmPercent = 80.0; // 0..100%

  // Safety Warnings & Failsafe
  bool _isLowBatteryAlert = false;
  bool _isAltitudeLimitBreach = false;
  bool _isWindWarning = false;
  bool _isFailsafeTriggered = false;

  // Waypoints & Autonomous Mission State
  List<FlightWaypoint> _missionWaypoints = [];
  int _currentWaypointIndex = 0;
  bool _isAutoMissionRunning = false;

  // Getters
  bool get isConnected => _isConnected;
  bool get isFlying => _isFlying;
  String get statusMessage => _statusMessage;
  String get currentHexPacket => _currentPacket.toHexString();
  DronePacket get currentPacket => _currentPacket;
  int get trimPitch => _trimPitch;
  int get trimRoll => _trimRoll;

  double get altitude => _altitude;
  double get speed => _speed;
  int get batteryPercent => _batteryPercent;
  double get headingDegrees => _headingDegrees;
  double get pitchAngle => _pitchAngle;
  double get rollAngle => _rollAngle;
  double get windSpeedMps => _windSpeedMps;

  bool get isSprayActive => _isSprayActive;
  double get sprayPwmPercent => _sprayPwmPercent;

  bool get isLowBatteryAlert => _isLowBatteryAlert;
  bool get isAltitudeLimitBreach => _isAltitudeLimitBreach;
  bool get isWindWarning => _isWindWarning;
  bool get isFailsafeTriggered => _isFailsafeTriggered;

  List<FlightWaypoint> get missionWaypoints => _missionWaypoints;
  int get currentWaypointIndex => _currentWaypointIndex;
  bool get isAutoMissionRunning => _isAutoMissionRunning;

  /// Connect and start 20Hz UDP Transmission Loop
  Future<bool> initialize({String? ip, int? port}) async {
    _droneIp = ip ?? DroneConstants.defaultDroneIp;
    _dronePort = port ?? DroneConstants.defaultControlPort;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _isConnected = true;
      _statusMessage = 'เชื่อมต่อ UDP $_droneIp:$_dronePort สำเร็จ';

      // Start 20Hz Heartbeat (50ms interval)
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(DroneConstants.heartbeatInterval, (_) {
        _sendCurrentPacket();
      });

      // Start Telemetry & Physics Simulator loop (100ms)
      _startTelemetrySimulation();

      HapticFeedback.mediumImpact();
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'โหมดจำลอง (Simulated Telemetry)';
      _startTelemetrySimulation(); // Run simulator anyway for demo
      notifyListeners();
      return false;
    }
  }

  void _startTelemetrySimulation() {
    _telemetrySimTimer?.cancel();
    _telemetrySimTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isFlying) {
        // Altitude follows throttle
        final targetAlt = (_currentPacket.throttle / 255.0) * 25.0;
        _altitude += (targetAlt - _altitude) * 0.08;
        if (_altitude < 0.2) _altitude = 0.2;

        // Speed follows pitch & roll
        final double rollOffset = (_currentPacket.roll - 128) / 128.0;
        final double pitchOffset = (_currentPacket.pitch - 128) / 128.0;
        _speed = (_speed * 0.9) + (pitchOffset.abs() * 4.5 + rollOffset.abs() * 3.5) * 0.1;

        // Heading follows yaw
        final double yawOffset = (_currentPacket.yaw - 128) / 128.0;
        _headingDegrees = (_headingDegrees + yawOffset * 2.5) % 360.0;
        if (_headingDegrees < 0) _headingDegrees += 360.0;

        _pitchAngle = pitchOffset * 25.0;
        _rollAngle = rollOffset * 25.0;

        // Battery slowly depletes
        if (_batteryPercent > 5 && (DateTime.now().second % 15 == 0)) {
          _batteryPercent--;
        }
      } else {
        _altitude = 0.0;
        _speed = 0.0;
        _pitchAngle = 0.0;
        _rollAngle = 0.0;
      }

      // Check Safety Limits
      _isLowBatteryAlert = _batteryPercent <= 20;
      _isAltitudeLimitBreach = _altitude >= 30.0;
      _isWindWarning = _windSpeedMps >= 8.0;

      if (_isLowBatteryAlert && _batteryPercent == 20) {
        HapticFeedback.heavyImpact();
      }

      notifyListeners();
    });
  }

  void updateSticks({
    int? roll,
    int? pitch,
    int? throttle,
    int? yaw,
  }) {
    if (roll != null) _currentPacket.roll = (roll + _trimRoll).clamp(0, 255);
    if (pitch != null) _currentPacket.pitch = (pitch + _trimPitch).clamp(0, 255);
    if (throttle != null) _currentPacket.throttle = throttle.clamp(0, 255);
    if (yaw != null) _currentPacket.yaw = yaw.clamp(0, 255);

    notifyListeners();
  }

  void adjustTrim({int deltaPitch = 0, int deltaRoll = 0}) {
    _trimPitch = (_trimPitch + deltaPitch).clamp(-30, 30);
    _trimRoll = (_trimRoll + deltaRoll).clamp(-30, 30);
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void takeoff() {
    _currentPacket.commandFlag = DroneConstants.cmdTakeoff;
    _isFlying = true;
    _altitude = 1.2;
    _statusMessage = '🚀 กำลังบินขึ้นสู่ความสูงโฮเวอร์ (Takeoff)...';
    HapticFeedback.heavyImpact();
    notifyListeners();

    Timer(const Duration(milliseconds: 1500), () {
      _currentPacket.commandFlag = DroneConstants.cmdNormal;
      _currentPacket.throttle = 128; // Mid hover
      _statusMessage = 'โฮเวอร์รักษาระดับ (Hover Stabilized)';
      notifyListeners();
    });
  }

  void land() {
    _currentPacket.commandFlag = DroneConstants.cmdLand;
    _statusMessage = '🛬 กำลังลงจอดอัตโนมัติ (Auto Landing)...';
    HapticFeedback.mediumImpact();
    notifyListeners();

    Timer(const Duration(milliseconds: 2500), () {
      _currentPacket.commandFlag = DroneConstants.cmdNormal;
      _currentPacket.throttle = 0;
      _isFlying = false;
      _altitude = 0.0;
      _statusMessage = 'โดรนลงจอดเรียบร้อย ปลอดภัย (Landed)';
      notifyListeners();
    });
  }

  void emergencyStop() {
    _currentPacket.commandFlag = DroneConstants.cmdEmergency;
    _currentPacket.throttle = 0;
    _currentPacket.pitch = 128;
    _currentPacket.roll = 128;
    _currentPacket.yaw = 128;
    _isFlying = false;
    _isFailsafeTriggered = true;
    _statusMessage = '🛑 ตัดการทำงานฉุกเฉิน (EMERGENCY CUT)!';
    HapticFeedback.heavyImpact();
    notifyListeners();

    Timer(const Duration(milliseconds: 800), () {
      _currentPacket.commandFlag = DroneConstants.cmdNormal;
      notifyListeners();
    });
  }

  void calibrateGyro() {
    _currentPacket.commandFlag = DroneConstants.cmdCalibrate;
    _statusMessage = '⚖️ กำลังตั้งค่าศูนย์ Gyroscope...';
    HapticFeedback.selectionClick();
    notifyListeners();

    Timer(const Duration(milliseconds: 1200), () {
      _currentPacket.commandFlag = DroneConstants.cmdNormal;
      _trimPitch = 0;
      _trimRoll = 0;
      _statusMessage = '✅ Calibrate Gyro สำเร็จ สมดุล 100%';
      notifyListeners();
    });
  }

  void toggleSpray() {
    _isSprayActive = !_isSprayActive;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void setSprayPwm(double val) {
    _sprayPwmPercent = val;
    notifyListeners();
  }

  /// Sets Mission Waypoints and runs automated survey path execution
  void setMissionWaypoints(List<FlightWaypoint> waypoints) {
    _missionWaypoints = waypoints;
    _currentWaypointIndex = 0;
    notifyListeners();
  }

  void startAutonomousMission() {
    if (_missionWaypoints.isEmpty) return;
    _isAutoMissionRunning = true;
    _currentWaypointIndex = 0;
    _isFlying = true;
    _statusMessage = '🛰️ กำลังปฏิบัติภารกิจบินอัตโนมัติ (Waypoints 1/${_missionWaypoints.length})';
    HapticFeedback.heavyImpact();
    notifyListeners();

    // Advance waypoints every 3 seconds for simulation
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isAutoMissionRunning || _currentWaypointIndex >= _missionWaypoints.length - 1) {
        timer.cancel();
        _isAutoMissionRunning = false;
        _statusMessage = '✅ ภารกิจสำรวจแปลงเกษตรสำเร็จ 100%';
        HapticFeedback.heavyImpact();
        notifyListeners();
        return;
      }
      _currentWaypointIndex++;
      _statusMessage = '🛰️ จุดบินที่ ${_currentWaypointIndex + 1}/${_missionWaypoints.length}';
      notifyListeners();
    });
  }

  void stopAutonomousMission() {
    _isAutoMissionRunning = false;
    _statusMessage = 'ยกเลิกภารกิจบินอัตโนมัติ สลับเป็น Manual';
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void _sendCurrentPacket() {
    if (_socket == null || !_isConnected) return;

    try {
      final bytes = _currentPacket.toBytes();
      _socket!.send(bytes, InternetAddress(_droneIp), _dronePort);
    } catch (e) {
      // Avoid blocking loop
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _telemetrySimTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
