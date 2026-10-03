import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TelemetryOverlay extends StatelessWidget {
  final double altitude;
  final double speed;
  final int battery;
  final double rollAngle;
  final double pitchAngle;
  final double headingDegrees;
  final double windSpeed;
  final bool isSprayActive;
  final bool isLowBattery;
  final bool isAltitudeBreach;
  final bool isWindWarning;

  const TelemetryOverlay({
    super.key,
    this.altitude = 12.5,
    this.speed = 3.2,
    this.battery = 85,
    this.rollAngle = 0.0,
    this.pitchAngle = 0.0,
    this.headingDegrees = 45.0,
    this.windSpeed = 2.4,
    this.isSprayActive = false,
    this.isLowBattery = false,
    this.isAltitudeBreach = false,
    this.isWindWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Artificial Horizon & Pitch Ladder Painter (Rotates with Roll & Moves with Pitch)
          Positioned.fill(
            child: CustomPaint(
              painter: _HorizonAndPitchLadderPainter(
                rollDeg: rollAngle,
                pitchDeg: pitchAngle,
              ),
            ),
          ),

          // 2. Spatial Agricultural Field Grid Overlay (AR Ground Perspective)
          Positioned.fill(
            child: CustomPaint(
              painter: _AgriSpatialGridPainter(),
            ),
          ),

          // 3. Central Target Reticle with Laser Distance
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(100, 100),
                  painter: _ReticlePainter(isSpray: isSprayActive),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
                  ),
                  child: Text(
                    'AGL: ${altitude.toStringAsFixed(1)}m | RNG: ${(altitude * 1.05).toStringAsFixed(1)}m',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.neonCyan),
                  ),
                ),
              ],
            ),
          ),

          // 4. Top Compass Tape
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('HDG: ${headingDegrees.round()}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonCyan)),
                    const Icon(
                      Icons.navigation,
                      size: 14,
                      color: AppTheme.neonGreen,
                    ),
                    Text(_getCardinalDirection(headingDegrees), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonGreen)),
                  ],
                ),
              ),
            ),
          ),

          // 5. Left & Right Telemetry Ribbons
          Positioned(
            top: 48,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRibbonChip(Icons.satellite_alt, 'ALTITUDE', '${altitude.toStringAsFixed(1)} m'),
                const SizedBox(height: 6),
                _buildRibbonChip(Icons.speed, 'SPD', '${speed.toStringAsFixed(1)} m/s'),
                const SizedBox(height: 6),
                _buildRibbonChip(Icons.air, 'WIND', '${windSpeed.toStringAsFixed(1)} m/s', color: isWindWarning ? AppTheme.neonRed : AppTheme.neonCyan),
              ],
            ),
          ),

          Positioned(
            top: 48,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildRibbonChip(
                  Icons.battery_charging_full,
                  'BATTERY',
                  '$battery%',
                  color: isLowBattery ? AppTheme.neonRed : AppTheme.neonGreen,
                ),
                const SizedBox(height: 6),
                _buildRibbonChip(
                  Icons.water_drop,
                  'SPRAY PUMP',
                  isSprayActive ? 'ACTIVE (ON)' : 'STANDBY',
                  color: isSprayActive ? AppTheme.neonGreen : AppTheme.textDim,
                ),
              ],
            ),
          ),

          // 6. Safety Warning Flash Banner (If any danger condition)
          if (isLowBattery || isAltitudeBreach || isWindWarning)
            Positioned(
              top: 86,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.neonRed.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(color: AppTheme.neonRed.withOpacity(0.6), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        isLowBattery
                            ? '⚠️ แบตเตอรี่ต่ำกว่า 20% กรุณานำโดรนลงจอดทันที (RTL Recommended)'
                            : isAltitudeBreach
                                ? '⚠️ ความสูงเกินเกณฑ์จำกัดความปลอดภัย (>30m)'
                                : '⚠️ ตรวจพบกระแสลมแรง (>8 m/s) ระวังการทรงตัว',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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

  String _getCardinalDirection(double deg) {
    if (deg >= 337.5 || deg < 22.5) return 'N (เหนือ)';
    if (deg >= 22.5 && deg < 67.5) return 'NE (ต.อ.น.)';
    if (deg >= 67.5 && deg < 112.5) return 'E (ตะวันออก)';
    if (deg >= 112.5 && deg < 157.5) return 'SE (ต.อ.ต.)';
    if (deg >= 157.5 && deg < 202.5) return 'S (ใต้)';
    if (deg >= 202.5 && deg < 247.5) return 'SW (ต.ต.ต.)';
    if (deg >= 247.5 && deg < 292.5) return 'W (ตะวันตก)';
    return 'NW (ต.ต.น.)';
  }

  Widget _buildRibbonChip(IconData icon, String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (color ?? AppTheme.neonCyan).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppTheme.neonCyan),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textDim, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 11, color: color ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HorizonAndPitchLadderPainter extends CustomPainter {
  final double rollDeg;
  final double pitchDeg;

  _HorizonAndPitchLadderPainter({required this.rollDeg, required this.pitchDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rollRad = rollDeg * (pi / 180.0);
    final pitchOffsetPx = pitchDeg * 3.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rollRad);

    final horizonPaint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Artificial Horizon Line
    canvas.drawLine(
      Offset(-120, pitchOffsetPx),
      Offset(-40, pitchOffsetPx),
      horizonPaint,
    );
    canvas.drawLine(
      Offset(40, pitchOffsetPx),
      Offset(120, pitchOffsetPx),
      horizonPaint,
    );

    // Pitch Ladder rungs (+10, -10 deg)
    for (int p in [10, 20, -10, -20]) {
      final y = pitchOffsetPx - (p * 3.5);
      final rungPaint = Paint()
        ..color = AppTheme.neonGreen.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(-30, y), Offset(30, y), rungPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HorizonAndPitchLadderPainter old) =>
      old.rollDeg != rollDeg || old.pitchDeg != pitchDeg;
}

class _AgriSpatialGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.neonGreen.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw perspective converging ground lines (simulating aerial orchard rows)
    final horizonY = size.height * 0.45;
    for (double x = size.width * 0.2; x <= size.width * 0.8; x += size.width * 0.12) {
      canvas.drawLine(
        Offset(size.width * 0.5 + (x - size.width * 0.5) * 0.1, horizonY),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReticlePainter extends CustomPainter {
  final bool isSpray;
  _ReticlePainter({required this.isSpray});

  @override
  void paint(Canvas canvas, Size size) {
    final reticleColor = isSpray ? AppTheme.neonYellow : AppTheme.neonGreen;
    final paint = Paint()
      ..color = reticleColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 18, paint);
    canvas.drawCircle(center, 3, Paint()..color = reticleColor..style = PaintingStyle.fill);

    // Crosshairs
    canvas.drawLine(Offset(center.dx - 36, center.dy), Offset(center.dx - 22, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 22, center.dy), Offset(center.dx + 36, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 36), Offset(center.dx, center.dy - 22), paint);
    canvas.drawLine(Offset(center.dx, center.dy + 22), Offset(center.dx, center.dy + 36), paint);

    // Corner targeting brackets
    const double b = 40;
    const double bl = 10;
    final bPaint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Top-Left
    canvas.drawLine(Offset(center.dx - b, center.dy - b), Offset(center.dx - b + bl, center.dy - b), bPaint);
    canvas.drawLine(Offset(center.dx - b, center.dy - b), Offset(center.dx - b, center.dy - b + bl), bPaint);
    // Top-Right
    canvas.drawLine(Offset(center.dx + b, center.dy - b), Offset(center.dx + b - bl, center.dy - b), bPaint);
    canvas.drawLine(Offset(center.dx + b, center.dy - b), Offset(center.dx + b, center.dy - b + bl), bPaint);
    // Bottom-Left
    canvas.drawLine(Offset(center.dx - b, center.dy + b), Offset(center.dx - b + bl, center.dy + b), bPaint);
    canvas.drawLine(Offset(center.dx - b, center.dy + b), Offset(center.dx - b, center.dy + b - bl), bPaint);
    // Bottom-Right
    canvas.drawLine(Offset(center.dx + b, center.dy + b), Offset(center.dx + b - bl, center.dy + b), bPaint);
    canvas.drawLine(Offset(center.dx + b, center.dy + b), Offset(center.dx + b, center.dy + b - bl), bPaint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) => old.isSpray != isSpray;
}
