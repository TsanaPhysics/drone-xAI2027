import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Comprehensive Agricultural & Physical Telemetry Analysis Result
class AgriAnalysisResult {
  // 1. Spectral & Health Metrics
  final double canopyCoveragePercent;
  final double meanVariIndex;
  final String healthGrade;
  final double stressPercent;
  final int healthyPixelCount;
  final int moderatePixelCount;
  final int stressedPixelCount;
  final int nonVegetationPixelCount;
  final Uint8List? processedHeatmapBytes;
  final List<String> agronomicAdvice;

  // 2. Physical & Spatial Quantification
  final double groundSampleDistanceCmPerPx; // GSD (cm/pixel)
  final double areaSqMeters;                // พื้นที่แปลงรวม (ตร.ม.)
  final double areaRai;                     // ไร่
  final double areaNgan;                    // งาน
  final double areaSqWah;                   // ตารางวา
  
  // 3. Plant & Tree Canopy Enumeration
  final int plantCount;                     // จำนวนต้นที่นับได้จริง
  final List<Offset> plantLocations;        // พิกัดจุดกึ่งกลางของแต่ละต้น (Normalized 0..1)
  final int missingPlantCount;              // จุดเว้าแหว่ง/ต้นที่ขาดหายไป
  final int replantingSeedlings;            // จำนวนต้นกล้าที่แนะนำให้ปลูกซ่อม

  // 4. Precision Spraying & Flow Analytics
  final double sprayRateLitersPerRai;       // อัตราการพ่น (ลิตร/ไร่)
  final double flowRateLitersPerMin;        // อัตราการไหลของหัวฉีด (ลิตร/นาที)
  final double requiredChemicalVolumeLiters; // ปริมาตรสารชีวภัณฑ์ที่ต้องใช้ทั้งแปลง (ลิตร)
  final double spraySwathMeters;            // ความกว้างแถบพ่น (เมตร)

  // 5. Energy & Flight Efficiency
  final double energyConsumptionWhPerRai;   // อัตราการใช้พลังงาน (Wh/ไร่)
  final double estimatedMissionTimeMinutes; // เวลาบินปฏิบัติการโดยประมาณ (นาที)

  final DateTime timestamp;

  AgriAnalysisResult({
    required this.canopyCoveragePercent,
    required this.meanVariIndex,
    required this.healthGrade,
    required this.stressPercent,
    required this.healthyPixelCount,
    required this.moderatePixelCount,
    required this.stressedPixelCount,
    required this.nonVegetationPixelCount,
    this.processedHeatmapBytes,
    required this.agronomicAdvice,
    required this.groundSampleDistanceCmPerPx,
    required this.areaSqMeters,
    required this.areaRai,
    required this.areaNgan,
    required this.areaSqWah,
    required this.plantCount,
    required this.plantLocations,
    required this.missingPlantCount,
    required this.replantingSeedlings,
    required this.sprayRateLitersPerRai,
    required this.flowRateLitersPerMin,
    required this.requiredChemicalVolumeLiters,
    required this.spraySwathMeters,
    required this.energyConsumptionWhPerRai,
    required this.estimatedMissionTimeMinutes,
    required this.timestamp,
  });

  factory AgriAnalysisResult.empty() {
    return AgriAnalysisResult(
      canopyCoveragePercent: 0.0,
      meanVariIndex: 0.0,
      healthGrade: 'รอการวิเคราะห์',
      stressPercent: 0.0,
      healthyPixelCount: 0,
      moderatePixelCount: 0,
      stressedPixelCount: 0,
      nonVegetationPixelCount: 0,
      agronomicAdvice: ['ยังไม่มีข้อมูลภาพถ่ายการบิน กรุณากดปุ่มถ่ายภาพหรือโหลดรูปแปลง'],
      groundSampleDistanceCmPerPx: 0.0,
      areaSqMeters: 0.0,
      areaRai: 0.0,
      areaNgan: 0.0,
      areaSqWah: 0.0,
      plantCount: 0,
      plantLocations: const [],
      missingPlantCount: 0,
      replantingSeedlings: 0,
      sprayRateLitersPerRai: 0.0,
      flowRateLitersPerMin: 0.0,
      requiredChemicalVolumeLiters: 0.0,
      spraySwathMeters: 2.5,
      energyConsumptionWhPerRai: 0.0,
      estimatedMissionTimeMinutes: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// String formatting for Thai traditional land measurements: X ไร่ Y งาน Z ตารางวา
  String get thaiLandMeasurementString {
    final r = areaRai.floor();
    final n = areaNgan.floor();
    final w = areaSqWah.toStringAsFixed(1);
    return '$r ไร่ $n งาน $w ตร.ว.';
  }
}
