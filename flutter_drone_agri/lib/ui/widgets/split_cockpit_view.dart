import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/drone_udp_service.dart';
import '../../services/agri_vision_service.dart';

enum SplitRightPanelMode {
  spectralHeatmap,
  miniFlightMap,
  sprayTelemetry,
}

class SplitCockpitView extends StatefulWidget {
  final DroneUdpService udpService;
  final AgriVisionService agriService;
  final VoidCallback onExpandFullscreen;

  const SplitCockpitView({
    super.key,
    required this.udpService,
    required this.agriService,
    required this.onExpandFullscreen,
  });

  @override
  State<SplitCockpitView> createState() => _SplitCockpitViewState();
}

class _SplitCockpitViewState extends State<SplitCockpitView> {
  SplitRightPanelMode _rightMode = SplitRightPanelMode.spectralHeatmap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Row(
        children: [
          // Left Half: FPV Video Feed Mock
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neonCyan.withOpacity(0.5)),
                gradient: RadialGradient(
                  colors: [const Color(0xFF1B4332).withOpacity(0.6), Colors.black],
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.videocam, size: 48, color: AppTheme.neonCyan),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text('FPV LIVE 1080P', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Divider with Toggle Buttons
          Container(
            width: 38,
            color: AppTheme.cardBg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.grass, size: 18),
                  tooltip: 'ดู Heatmap สเปกตรัม',
                  color: _rightMode == SplitRightPanelMode.spectralHeatmap ? AppTheme.neonGreen : AppTheme.textDim,
                  onPressed: () => setState(() => _rightMode = SplitRightPanelMode.spectralHeatmap),
                ),
                IconButton(
                  icon: const Icon(Icons.map, size: 18),
                  tooltip: 'ดูแผนที่แปลงเกษตร',
                  color: _rightMode == SplitRightPanelMode.miniFlightMap ? AppTheme.neonCyan : AppTheme.textDim,
                  onPressed: () => setState(() => _rightMode = SplitRightPanelMode.miniFlightMap),
                ),
                IconButton(
                  icon: const Icon(Icons.water_drop, size: 18),
                  tooltip: 'ดูสถานะการพ่นยา',
                  color: _rightMode == SplitRightPanelMode.sprayTelemetry ? AppTheme.neonYellow : AppTheme.textDim,
                  onPressed: () => setState(() => _rightMode = SplitRightPanelMode.sprayTelemetry),
                ),
                const Divider(color: Colors.white24, height: 16),
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 18, color: Colors.white),
                  tooltip: 'กลับสู่จอเดี่ยวเต็มจอ',
                  onPressed: widget.onExpandFullscreen,
                ),
              ],
            ),
          ),

          // Right Half: Dual Analytics Display
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.5)),
                color: AppTheme.cardBg,
              ),
              child: _buildRightPanelContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanelContent() {
    switch (_rightMode) {
      case SplitRightPanelMode.spectralHeatmap:
        return _buildHeatmapPanel();
      case SplitRightPanelMode.miniFlightMap:
        return _buildMapPanel();
      case SplitRightPanelMode.sprayTelemetry:
        return _buildSprayPanel();
    }
  }

  Widget _buildHeatmapPanel() {
    final result = widget.agriService.lastResult;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE SPECTRAL HEATMAP (${widget.agriService.activeFilter.name.toUpperCase()})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonGreen),
              ),
              Text(
                result.healthGrade,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonYellow),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.nature_people, size: 36, color: AppTheme.neonGreen),
                    const SizedBox(height: 4),
                    Text(
                      'VARI: ${result.meanVariIndex.toStringAsFixed(3)} | Canopy: ${result.canopyCoveragePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 10, color: AppTheme.neonCyan),
                    ),
                    Text(
                      'นับต้นพืชได้: ${result.plantCount} ต้น | จุดแหว่ง: ${result.missingPlantCount}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textDim),
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

  Widget _buildMapPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SURVEY MAP & GEOFENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonCyan)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF142018),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _MiniMapPainter(),
                  ),
                  const Positioned(
                    bottom: 6,
                    left: 6,
                    child: Text(
                      'POS: 12.6542° N, 102.1245° E | RBRU Smart Farm',
                      style: TextStyle(fontSize: 9, color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSprayPanel() {
    final udp = widget.udpService;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PRECISION SPRAY CONTROL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonYellow)),
              Switch(
                value: udp.isSprayActive,
                activeThumbColor: AppTheme.neonGreen,
                onChanged: (_) => udp.toggleSpray(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('PWM Pump: ', style: TextStyle(fontSize: 10, color: AppTheme.textDim)),
              Expanded(
                child: Slider(
                  value: udp.sprayPwmPercent,
                  min: 20,
                  max: 100,
                  divisions: 8,
                  activeColor: AppTheme.neonYellow,
                  onChanged: (v) => udp.setSprayPwm(v),
                ),
              ),
              Text('${udp.sprayPwmPercent.round()}%', style: const TextStyle(fontSize: 11, color: AppTheme.neonYellow, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildStatRow('Flow Rate (อัตราไหล):', '${(udp.sprayPwmPercent * 0.025).toStringAsFixed(2)} L/min'),
                const SizedBox(height: 4),
                _buildStatRow('Tank Level (ถังคงเหลือ):', '78% (7.8 ลิตร)'),
                const SizedBox(height: 4),
                _buildStatRow('Coverage Efficiency:', '4.8 ไร่/เที่ยวบิน'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textDim)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw polygon geofence field
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.2)
      ..lineTo(size.width * 0.85, size.height * 0.15)
      ..lineTo(size.width * 0.9, size.height * 0.8)
      ..lineTo(size.width * 0.2, size.height * 0.85)
      ..close();

    final fillPaint = Paint()
      ..color = AppTheme.neonGreen.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppTheme.neonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw Lawnmower survey path
    final linePaint = Paint()
      ..color = AppTheme.neonCyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double y = size.height * 0.3; y <= size.height * 0.75; y += size.height * 0.12) {
      canvas.drawLine(Offset(size.width * 0.25, y), Offset(size.width * 0.8, y), linePaint);
    }

    // Drone Icon position
    final dronePaint = Paint()..color = AppTheme.neonYellow;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 5, dronePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
