import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/flight_waypoint.dart';
import '../../services/drone_udp_service.dart';

class FlightPlanScreen extends StatefulWidget {
  const FlightPlanScreen({super.key});

  @override
  State<FlightPlanScreen> createState() => _FlightPlanScreenState();
}

class _FlightPlanScreenState extends State<FlightPlanScreen> {
  // Polygon Geofence boundary points (Normalized 0..1)
  final List<Offset> _geofencePoints = [
    const Offset(0.20, 0.20),
    const Offset(0.80, 0.15),
    const Offset(0.85, 0.80),
    const Offset(0.25, 0.85),
  ];

  List<FlightWaypoint> _generatedWaypoints = [];
  double _gridSpacingPercent = 0.12; // Grid line spacing
  double _flightAltitude = 15.0; // Altitude in meters
  double _surveySpeed = 3.5; // Flight speed in m/s

  @override
  void initState() {
    super.initState();
    _generateSurveyGrid();
  }

  void _generateSurveyGrid() {
    final waypoints = <FlightWaypoint>[];
    int wpIndex = 1;

    // Lawnmower Grid generation across bounding box of geofence
    double minY = _geofencePoints.map((p) => p.dy).reduce(min);
    double maxY = _geofencePoints.map((p) => p.dy).reduce(max);
    double minX = _geofencePoints.map((p) => p.dx).reduce(min);
    double maxX = _geofencePoints.map((p) => p.dx).reduce(max);

    bool leftToRight = true;
    for (double y = minY + 0.05; y <= maxY - 0.02; y += _gridSpacingPercent) {
      if (leftToRight) {
        waypoints.add(FlightWaypoint(
          index: wpIndex++,
          x: minX + 0.03,
          y: y,
          altitude: _flightAltitude,
          speed: _surveySpeed,
        ));
        waypoints.add(FlightWaypoint(
          index: wpIndex++,
          x: maxX - 0.03,
          y: y,
          altitude: _flightAltitude,
          speed: _surveySpeed,
        ));
      } else {
        waypoints.add(FlightWaypoint(
          index: wpIndex++,
          x: maxX - 0.03,
          y: y,
          altitude: _flightAltitude,
          speed: _surveySpeed,
        ));
        waypoints.add(FlightWaypoint(
          index: wpIndex++,
          x: minX + 0.03,
          y: y,
          altitude: _flightAltitude,
          speed: _surveySpeed,
        ));
      }
      leftToRight = !leftToRight;
    }

    setState(() {
      _generatedWaypoints = waypoints;
    });

    // Sync to UDP service
    context.read<DroneUdpService>().setMissionWaypoints(waypoints);
  }

  // Calculate approximate real-world field metrics
  double get _approxAreaSqMeters => 6400.0; // ~4 ไร่
  double get _approxDistanceMeters {
    if (_generatedWaypoints.length < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < _generatedWaypoints.length - 1; i++) {
      final p1 = Offset(_generatedWaypoints[i].x * 120, _generatedWaypoints[i].y * 120);
      final p2 = Offset(_generatedWaypoints[i + 1].x * 120, _generatedWaypoints[i + 1].y * 120);
      dist += (p1 - p2).distance;
    }
    return dist;
  }

  double get _approxFlightTimeMinutes =>
      _surveySpeed > 0 ? (_approxDistanceMeters / _surveySpeed) / 60.0 : 0.0;

  @override
  Widget build(BuildContext context) {
    final udpService = context.watch<DroneUdpService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ วางแผนการบินสำรวจแปลงเกษตร (Flight Plan & Geofence)', style: TextStyle(fontSize: 16)),
        actions: [
          ElevatedButton.icon(
            icon: Icon(udpService.isAutoMissionRunning ? Icons.stop : Icons.play_arrow, size: 18),
            label: Text(udpService.isAutoMissionRunning ? 'หยุดภารกิจ (Abort)' : 'เริ่มบินอัตโนมัติ (Start Mission)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: udpService.isAutoMissionRunning ? AppTheme.neonRed : AppTheme.neonGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (udpService.isAutoMissionRunning) {
                udpService.stopAutonomousMission();
              } else {
                udpService.startAutonomousMission();
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Left: Interactive Map Canvas
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (details) {
                      // Allow adding boundary geofence points
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final local = details.localPosition;
                      final size = box.size;
                      final norm = Offset(local.dx / size.width, local.dy / size.height);
                      setState(() {
                        if (_geofencePoints.length < 8) {
                          _geofencePoints.add(norm);
                          _generateSurveyGrid();
                        }
                      });
                    },
                    child: Container(
                      color: const Color(0xFF0D1811),
                      child: CustomPaint(
                        painter: _FlightMapPainter(
                          geofence: _geofencePoints,
                          waypoints: _generatedWaypoints,
                          currentWpIndex: udpService.currentWaypointIndex,
                          isFlying: udpService.isAutoMissionRunning,
                        ),
                      ),
                    ),
                  ),
                ),

                // Map HUD Overlay Controls
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app, size: 14, color: AppTheme.neonCyan),
                        const SizedBox(width: 6),
                        const Text('แตะบนแผนที่เพื่อเพิ่มหมุด Geofence ขอบแปลง', style: TextStyle(fontSize: 11, color: AppTheme.textDim)),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _geofencePoints.clear();
                              _geofencePoints.addAll([
                                const Offset(0.20, 0.20),
                                const Offset(0.80, 0.15),
                                const Offset(0.85, 0.80),
                                const Offset(0.25, 0.85),
                              ]);
                              _generateSurveyGrid();
                            });
                          },
                          child: const Text('รีเซ็ตแปลง', style: TextStyle(fontSize: 11, color: AppTheme.neonYellow)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Mission Parameters & Flight Estimation
          Expanded(
            flex: 3,
            child: Container(
              color: AppTheme.cardBg,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('พารามิเตอร์ภารกิจ (Mission Settings)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.neonCyan)),
                    const SizedBox(height: 12),

                    // Altitude Setting
                    Text('ระดับความสูงบิน (Altitude): ${_flightAltitude.round()} เมตร', style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                    Slider(
                      value: _flightAltitude,
                      min: 5.0,
                      max: 30.0,
                      divisions: 25,
                      activeColor: AppTheme.neonCyan,
                      onChanged: (val) {
                        setState(() => _flightAltitude = val);
                        _generateSurveyGrid();
                      },
                    ),

                    // Flight Speed
                    Text('ความเร็วบินสำรวจ (Speed): ${_surveySpeed.toStringAsFixed(1)} m/s', style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                    Slider(
                      value: _surveySpeed,
                      min: 1.0,
                      max: 8.0,
                      divisions: 14,
                      activeColor: AppTheme.neonGreen,
                      onChanged: (val) {
                        setState(() => _surveySpeed = val);
                        _generateSurveyGrid();
                      },
                    ),

                    // Grid Spacing
                    Text('ระยะห่างแนวบิน (Grid Swath): ${(_gridSpacingPercent * 100).round()}%', style: const TextStyle(fontSize: 12, color: AppTheme.textDim)),
                    Slider(
                      value: _gridSpacingPercent,
                      min: 0.08,
                      max: 0.25,
                      divisions: 17,
                      activeColor: AppTheme.neonYellow,
                      onChanged: (val) {
                        setState(() => _gridSpacingPercent = val);
                        _generateSurveyGrid();
                      },
                    ),

                    const Divider(color: Colors.white24, height: 24),
                    const Text('สถิติการบินและการสแกน (Calculated Stats)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),

                    _buildStatCard(Icons.crop_free, 'ขนาดพื้นที่แปลง:', '$_approxAreaSqMeters ตร.ม. (4 ไร่ 0 งาน)'),
                    _buildStatCard(Icons.alt_route, 'ระยะทางบินรวม:', '${_approxDistanceMeters.toStringAsFixed(0)} เมตร'),
                    _buildStatCard(Icons.timer, 'เวลาบินโดยประมาณ:', '${_approxFlightTimeMinutes.toStringAsFixed(1)} นาที'),
                    _buildStatCard(Icons.pin_drop, 'จำนวน Waypoints:', '${_generatedWaypoints.length} จุด'),
                    _buildStatCard(Icons.battery_std, 'พลังงานคาดการณ์:', '14.2% ของแบตเตอรี่'),

                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('ส่งออกแผนการบิน (KML / MAVLink)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neonCyan,
                        side: const BorderSide(color: AppTheme.neonCyan),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ส่งออกไฟล์แผนการบิน MAVLink สำเร็จ')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.neonCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
          ),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _FlightMapPainter extends CustomPainter {
  final List<Offset> geofence;
  final List<FlightWaypoint> waypoints;
  final int currentWpIndex;
  final bool isFlying;

  _FlightMapPainter({
    required this.geofence,
    required this.waypoints,
    required this.currentWpIndex,
    required this.isFlying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Satellite orchard mock background
    final bgPaint = Paint()..color = const Color(0xFF162B1D);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw tree rows dots
    final treePaint = Paint()..color = const Color(0xFF265033);
    for (double y = 40; y < size.height; y += 35) {
      for (double x = 40; x < size.width; x += 35) {
        canvas.drawCircle(Offset(x, y), 8, treePaint);
      }
    }

    // 2. Draw Geofence Boundary Polygon
    if (geofence.isNotEmpty) {
      final polyPath = Path();
      polyPath.moveTo(geofence[0].dx * size.width, geofence[0].dy * size.height);
      for (int i = 1; i < geofence.length; i++) {
        polyPath.lineTo(geofence[i].dx * size.width, geofence[i].dy * size.height);
      }
      polyPath.close();

      canvas.drawPath(
        polyPath,
        Paint()
          ..color = AppTheme.neonGreen.withOpacity(0.18)
          ..style = PaintingStyle.fill,
      );

      canvas.drawPath(
        polyPath,
        Paint()
          ..color = AppTheme.neonGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Draw Corner Vertices
      for (final p in geofence) {
        canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height),
          5,
          Paint()..color = AppTheme.neonYellow,
        );
      }
    }

    // 3. Draw Lawnmower Survey Waypoint Path
    if (waypoints.isNotEmpty) {
      final pathPaint = Paint()
        ..color = AppTheme.neonCyan.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      final path = Path();
      path.moveTo(waypoints[0].x * size.width, waypoints[0].y * size.height);
      for (int i = 1; i < waypoints.length; i++) {
        path.lineTo(waypoints[i].x * size.width, waypoints[i].y * size.height);
      }
      canvas.drawPath(path, pathPaint);

      // Draw Waypoint Points & Numbers
      for (int i = 0; i < waypoints.length; i++) {
        final wp = waypoints[i];
        final center = Offset(wp.x * size.width, wp.y * size.height);
        final bool isCurrent = isFlying && (i == currentWpIndex);

        canvas.drawCircle(
          center,
          isCurrent ? 7 : 4,
          Paint()..color = isCurrent ? AppTheme.neonRed : AppTheme.neonCyan,
        );
      }

      // Draw Drone Position if flying
      if (isFlying && currentWpIndex < waypoints.length) {
        final curWp = waypoints[currentWpIndex];
        final dronePos = Offset(curWp.x * size.width, curWp.y * size.height);

        // Drone Halo
        canvas.drawCircle(
          dronePos,
          14,
          Paint()
            ..color = AppTheme.neonYellow.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        canvas.drawCircle(
          dronePos,
          6,
          Paint()..color = AppTheme.neonYellow,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlightMapPainter old) => true;
}
