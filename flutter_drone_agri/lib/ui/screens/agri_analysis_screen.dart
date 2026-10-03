import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/agri_analysis_result.dart';
import '../../services/agri_vision_service.dart';

class AgriAnalysisScreen extends StatelessWidget {
  const AgriAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final agriService = context.watch<AgriVisionService>();
    final result = agriService.lastResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛰️ วิเคราะห์ภาพแปลงเกษตรแม่นยำ (Agri-Vision Pro)', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'ทดสอบวิเคราะห์ภาพแปลงสาธิต (Durian Orchard Demo)',
            onPressed: () {
              agriService.runDemoAnalysis();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('กำลังประมวลผลวิเคราะห์สเปกตรัมและนับต้นพืช...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'ส่งออกรายงานสรุป',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ส่งออกรายงานสถิติสุขภาพแปลงพืชและพิกัดต้นไม้เรียบร้อย')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Demo Runner & Tree Markers Toggle
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('จำลองสแกนแปลงทุเรียน (Durian Orchard)', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => agriService.runDemoAnalysis(),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: agriService.showTreeMarkers,
                  label: Text('แสดงจุดมาร์กเกอร์ต้นไม้ (${result.plantCount} ต้น)', style: const TextStyle(fontSize: 12)),
                  selectedColor: AppTheme.neonCyan.withOpacity(0.3),
                  checkmarkColor: AppTheme.neonCyan,
                  onSelected: (_) => agriService.toggleTreeMarkers(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'VARI Index', SpectralFilterType.vari, agriService),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'GLI Index', SpectralFilterType.gli, agriService),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'ExG (Excess Green)', SpectralFilterType.exg, agriService),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'Visible NDVI', SpectralFilterType.vNdvi, agriService),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'Canopy Mask', SpectralFilterType.canopyMask, agriService),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'RGB True Color', SpectralFilterType.rgb, agriService),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Heatmap Viewport with Dynamic Tree Centroid Markers
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: _HeatmapCanvasPainter(
                          result: result,
                          filter: agriService.activeFilter,
                          showTrees: agriService.showTreeMarkers,
                        ),
                      ),
                    ),
                  ),

                  // Top Overlay Badges
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'FALSE-COLOR: ${agriService.activeFilter.name.toUpperCase()}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getGradeColor(result.healthGrade).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getGradeColor(result.healthGrade)),
                      ),
                      child: Text(
                        result.healthGrade,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getGradeColor(result.healthGrade)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sensitivity & Altitude Sliders
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ความไวตัดทรงพุ่ม (Threshold): ${agriService.sensitivityThreshold.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
                      Slider(
                        value: agriService.sensitivityThreshold,
                        min: 0.02,
                        max: 0.35,
                        divisions: 15,
                        activeColor: AppTheme.neonGreen,
                        onChanged: (val) => agriService.setSensitivity(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ระดับความสูงบิน (Altitude): ${agriService.flightAltitudeMeters.round()} เมตร', style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
                      Slider(
                        value: agriService.flightAltitudeMeters,
                        min: 5.0,
                        max: 30.0,
                        divisions: 25,
                        activeColor: AppTheme.neonCyan,
                        onChanged: (val) => agriService.setFlightAltitude(val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantitative Measurement Metric Cards Grid
            const Text('การตรวจวัดและการวิเคราะห์เชิงปริมาณ (Quantitative Analytics)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'ขนาดพื้นที่แปลงจริง',
                    result.thaiLandMeasurementString,
                    '${result.areaSqMeters.toStringAsFixed(0)} ตร.ม. (GSD: ${result.groundSampleDistanceCmPerPx.toStringAsFixed(1)} ซม./px)',
                    Icons.square_foot,
                    AppTheme.neonCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'การนับต้นพืช / ทรงพุ่ม',
                    '${result.plantCount} ต้น',
                    'พบจุดเว้าแหว่ง/ขาด: ${result.missingPlantCount} จุด (ปลูกซ่อม)',
                    Icons.nature,
                    AppTheme.neonGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'การพ่นสารชีวภัณฑ์แม่นยำ',
                    '${result.sprayRateLitersPerRai.toStringAsFixed(1)} ลิตร/ไร่',
                    'Flow Rate: ${result.flowRateLitersPerMin.toStringAsFixed(2)} L/min | รวม ${result.requiredChemicalVolumeLiters.toStringAsFixed(1)} L',
                    Icons.water_drop,
                    AppTheme.neonYellow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'การประเมินสเปกตรัม',
                    'VARI: ${result.meanVariIndex.toStringAsFixed(3)}',
                    'ทรงพุ่ม: ${result.canopyCoveragePercent.toStringAsFixed(1)}% | เครียด: ${result.stressPercent.toStringAsFixed(1)}%',
                    Icons.analytics,
                    AppTheme.neonGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Agronomic Advice Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates, size: 18, color: AppTheme.neonYellow),
                      SizedBox(width: 8),
                      Text('คำแนะนำเชิงเกษตรวิทยาและการจัดการแปลง (Agronomic Advice)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...result.agronomicAdvice.map(
                    (adv) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(adv, style: const TextStyle(fontSize: 12, color: AppTheme.textDim, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, SpectralFilterType type, AgriVisionService service) {
    final isSelected = service.activeFilter == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white)),
      selected: isSelected,
      selectedColor: AppTheme.neonGreen,
      backgroundColor: AppTheme.cardBg,
      onSelected: (_) => service.setFilter(type),
    );
  }

  Widget _buildMetricTile(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
            ],
          ),
          const SizedBox(height: 6),
          Text(mainValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subValue, style: const TextStyle(fontSize: 10, color: AppTheme.textDim)),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.contains('A')) return AppTheme.neonGreen;
    if (grade.contains('B')) return AppTheme.neonYellow;
    return AppTheme.neonRed;
  }
}

class _HeatmapCanvasPainter extends CustomPainter {
  final AgriAnalysisResult result;
  final SpectralFilterType filter;
  final bool showTrees;

  _HeatmapCanvasPainter({
    required this.result,
    required this.filter,
    required this.showTrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF14241B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw Simulated Orchard rows
    final rowPaint = Paint()..color = const Color(0xFF1D3B2A);
    for (double y = 20; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rowPaint);
    }

    // Draw Detected Plant Centroids
    if (showTrees && result.plantLocations.isNotEmpty) {
      final treePaint = Paint()
        ..color = AppTheme.neonYellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final fillPaint = Paint()
        ..color = AppTheme.neonYellow.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < result.plantLocations.length; i++) {
        final loc = result.plantLocations[i];
        final center = Offset(loc.dx * size.width, loc.dy * size.height);
        canvas.drawCircle(center, 12, fillPaint);
        canvas.drawCircle(center, 12, treePaint);
        canvas.drawCircle(center, 2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapCanvasPainter old) => true;
}
