import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/agri_analysis_result.dart';

enum SpectralFilterType {
  rgb,
  vari,
  gli,
  exg,
  vNdvi,
  canopyMask,
}

class AgriVisionService extends ChangeNotifier {
  SpectralFilterType _activeFilter = SpectralFilterType.vari;
  double _sensitivityThreshold = 0.12;
  double _flightAltitudeMeters = 15.0; // ความสูงบินเฉลี่ย (เมตร)
  double _sprayTargetDosageLPerRai = 4.5; // ปริมาณพ่นเป้าหมาย (ลิตร/ไร่)
  final double _spraySwathMeters = 2.5; // ความกว้างแนวพ่น (เมตร)
  bool _showTreeMarkers = true;

  AgriAnalysisResult _lastResult = AgriAnalysisResult.empty();
  bool _isProcessing = false;

  SpectralFilterType get activeFilter => _activeFilter;
  double get sensitivityThreshold => _sensitivityThreshold;
  double get flightAltitudeMeters => _flightAltitudeMeters;
  double get sprayTargetDosageLPerRai => _sprayTargetDosageLPerRai;
  double get spraySwathMeters => _spraySwathMeters;
  bool get showTreeMarkers => _showTreeMarkers;
  AgriAnalysisResult get lastResult => _lastResult;
  bool get isProcessing => _isProcessing;

  void setFilter(SpectralFilterType filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setSensitivity(double val) {
    _sensitivityThreshold = val;
    notifyListeners();
  }

  void setFlightAltitude(double alt) {
    _flightAltitudeMeters = alt;
    notifyListeners();
  }

  void setSprayTargetDosage(double dosage) {
    _sprayTargetDosageLPerRai = dosage;
    notifyListeners();
  }

  void toggleTreeMarkers() {
    _showTreeMarkers = !_showTreeMarkers;
    notifyListeners();
  }

  /// Analyze RGBA Pixel Buffer (Supports camera snapshot or sample buffer)
  Future<AgriAnalysisResult> analyzeRgbaPixels({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) async {
    _isProcessing = true;
    notifyListeners();

    final result = await compute(_runSpectralProcessing, _ProcessingParams(
      rgbaBytes: rgbaBytes,
      width: width,
      height: height,
      filter: _activeFilter,
      threshold: _sensitivityThreshold,
      altitudeMeters: _flightAltitudeMeters,
      targetDosageLPerRai: _sprayTargetDosageLPerRai,
      spraySwathMeters: _spraySwathMeters,
    ));

    _lastResult = result;
    _isProcessing = false;
    notifyListeners();
    return result;
  }

  /// Generates a realistic synthetic Durian/Fruit Orchard RGB image (240x180) for testing
  Future<void> runDemoAnalysis() async {
    const int w = 240;
    const int h = 180;
    final Uint8List mockRgba = Uint8List(w * h * 4);
    final random = Random(42);

    // Simulate orchard with grid pattern of durian trees and soil pathways
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int idx = (y * w + x) * 4;
        
        // Soil base color (Brown/Sandy loam)
        int r = 160 + random.nextInt(25);
        int g = 135 + random.nextInt(20);
        int b = 95 + random.nextInt(20);

        // Grid of fruit trees (e.g. 5x4 grid of trees)
        final double gridX = x / 40.0;
        final double gridY = y / 40.0;
        final double centerX = (gridX.floor() + 0.5) * 40.0;
        final double centerY = (gridY.floor() + 0.5) * 40.0;
        final double dist = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2));

        // Skip two tree spots to simulate "missing/dead trees" (Gaps)
        final bool isMissingTree = (gridX.floor() == 1 && gridY.floor() == 1) || 
                                   (gridX.floor() == 4 && gridY.floor() == 2);

        if (!isMissingTree && dist < 14) {
          // Tree foliage with chlorophyll
          final double foliageFactor = 1.0 - (dist / 14.0);
          final bool isStressed = (gridX.floor() == 3 && gridY.floor() == 1); // 1 tree stressed

          if (isStressed) {
            // Yellowing chlorosis/stressed
            r = (180 + foliageFactor * 40).round().clamp(0, 255);
            g = (160 + foliageFactor * 30).round().clamp(0, 255);
            b = 40;
          } else {
            // Vibrant Healthy Green
            r = (35 + random.nextInt(15)).clamp(0, 255);
            g = (140 + (foliageFactor * 80).round() + random.nextInt(20)).clamp(0, 255);
            b = (40 + random.nextInt(20)).clamp(0, 255);
          }
        }

        mockRgba[idx] = r;
        mockRgba[idx + 1] = g;
        mockRgba[idx + 2] = b;
        mockRgba[idx + 3] = 255;
      }
    }

    await analyzeRgbaPixels(rgbaBytes: mockRgba, width: w, height: h);
  }
}

class _ProcessingParams {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final SpectralFilterType filter;
  final double threshold;
  final double altitudeMeters;
  final double targetDosageLPerRai;
  final double spraySwathMeters;

  _ProcessingParams({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.filter,
    required this.threshold,
    required this.altitudeMeters,
    required this.targetDosageLPerRai,
    required this.spraySwathMeters,
  });
}

AgriAnalysisResult _runSpectralProcessing(_ProcessingParams params) {
  final src = params.rgbaBytes;
  final int width = params.width;
  final int height = params.height;
  final int totalPixels = width * height;
  final Uint8List heatmap = Uint8List(src.length);

  int canopyCount = 0;
  double sumVari = 0;
  int countHealthy = 0;
  int countModerate = 0;
  int countStressed = 0;
  int countSoil = 0;

  // 1. Pixel-by-pixel Spectral Indices Computation
  final List<double> variGrid = List<double>.filled(totalPixels, 0.0);

  for (int p = 0; p < totalPixels; p++) {
    final int i = p * 4;
    final int r = src[i];
    final int g = src[i + 1];
    final int b = src[i + 2];

    // VARI = (G - R) / (G + R - B)
    final double variDenom = (g + r - b).toDouble();
    final double vari = variDenom != 0 ? ((g - r) / variDenom).clamp(-1.0, 1.0) : 0.0;
    variGrid[p] = vari;

    // GLI = (2G - R - B) / (2G + R + B)
    final double gliDenom = (2 * g + r + b).toDouble();
    final double gli = gliDenom != 0 ? ((2 * g - r - b) / gliDenom).clamp(-1.0, 1.0) : 0.0;

    // ExG = (2G - R - B) / 255.0
    final double exg = (2 * g - r - b) / 255.0;

    // Visible NDVI approx
    final double vNdvi = (g + r > 0) ? (g - r) / (g + r) : 0.0;

    final bool isCanopy = vari >= params.threshold;

    if (isCanopy) {
      canopyCount++;
      sumVari += vari;

      if (vari > 0.28) {
        countHealthy++;
      } else if (vari > 0.14) {
        countModerate++;
      } else {
        countStressed++;
      }
    } else {
      countSoil++;
    }

    // False-Color Heatmap Generation
    if (params.filter == SpectralFilterType.rgb) {
      heatmap[i] = r;
      heatmap[i + 1] = g;
      heatmap[i + 2] = b;
      heatmap[i + 3] = 255;
    } else if (params.filter == SpectralFilterType.canopyMask) {
      if (isCanopy) {
        heatmap[i] = 0;
        heatmap[i + 1] = 255;
        heatmap[i + 2] = 120;
        heatmap[i + 3] = 255;
      } else {
        final int gray = ((0.299 * r + 0.587 * g + 0.114 * b) * 0.25).round();
        heatmap[i] = gray;
        heatmap[i + 1] = gray;
        heatmap[i + 2] = gray;
        heatmap[i + 3] = 255;
      }
    } else {
      double target = vari;
      if (params.filter == SpectralFilterType.gli) target = gli;
      if (params.filter == SpectralFilterType.exg) target = exg;
      if (params.filter == SpectralFilterType.vNdvi) target = vNdvi;

      final color = _mapSpectralColor(target);
      heatmap[i] = color[0];
      heatmap[i + 1] = color[1];
      heatmap[i + 2] = color[2];
      heatmap[i + 3] = 255;
    }
  }

  // 2. Plant / Tree Counting & Local Maxima Centroid Detection
  final List<Offset> detectedPlants = [];
  const int step = 16; // Grid step for peak search
  int gapCount = 0;

  for (int cy = step; cy < height - step; cy += step) {
    for (int cx = step; cx < width - step; cx += step) {
      double maxLocalVari = -1.0;
      int peakX = cx;
      int peakY = cy;

      for (int dy = -step ~/ 2; dy <= step ~/ 2; dy += 2) {
        for (int dx = -step ~/ 2; dx <= step ~/ 2; dx += 2) {
          final int py = cy + dy;
          final int px = cx + dx;
          final int pIdx = py * width + px;
          if (pIdx >= 0 && pIdx < totalPixels) {
            final v = variGrid[pIdx];
            if (v > maxLocalVari) {
              maxLocalVari = v;
              peakX = px;
              peakY = py;
            }
          }
        }
      }

      if (maxLocalVari > (params.threshold + 0.08)) {
        // Valid tree centroid found
        final normX = peakX / width;
        final normY = peakY / height;
        
        // Prevent duplicate centroids too close to each other
        bool isDuplicate = false;
        for (final p in detectedPlants) {
          final distSq = pow(p.dx - normX, 2) + pow(p.dy - normY, 2);
          if (distSq < 0.003) {
            isDuplicate = true;
            break;
          }
        }

        if (!isDuplicate) {
          detectedPlants.add(Offset(normX, normY));
        }
      } else {
        // Potential gap / missing seedling spot
        gapCount++;
      }
    }
  }

  // Normalize gap count to realistic seedling planting scale
  final int estimatedGaps = (gapCount / 6.0).round().clamp(1, 15);

  // 3. Physical & Spatial Quantification (GSD & Thai Acreage)
  // GSD = (H * SensorWidth) / (FocalLength * ImageWidth)
  // Default camera: sensor 4.5mm, focal length 3.6mm
  final double gsdCm = (params.altitudeMeters * 4.5 / (3.6 * width)) * 100.0;
  final double groundWidthMeters = (width * gsdCm) / 100.0;
  final double groundHeightMeters = (height * gsdCm) / 100.0;
  final double totalAreaSqMeters = groundWidthMeters * groundHeightMeters;

  // Thai Area Units: 1 ไร่ = 1,600 ตร.ม., 1 งาน = 400 ตร.ม., 1 ตร.ว. = 4 ตร.ม.
  final double totalRai = totalAreaSqMeters / 1600.0;
  final double remAfterRai = totalAreaSqMeters % 1600.0;
  final double totalNgan = remAfterRai / 400.0;
  final double remAfterNgan = remAfterRai % 400.0;
  final double totalSqWah = remAfterNgan / 4.0;

  // 4. Precision Spraying & Flow Analytics
  // Flow Rate Q (L/min) = (SprayRate [L/rai] * FlightSpeed [m/s] * Swath [m] * 60) / 1600
  const double avgFlightSpeedMps = 3.0; // 3 m/s
  final double flowRateLPerMin = (params.targetDosageLPerRai * avgFlightSpeedMps * params.spraySwathMeters * 60.0) / 1600.0;
  final double requiredChemicalLiters = totalRai * params.targetDosageLPerRai;

  // 5. Energy & Mission Duration
  const double energyWhPerRai = 68.5; // Typical 4-rotor drone battery draw (Wh/rai)
  final double flightDurationMin = (totalAreaSqMeters / (avgFlightSpeedMps * params.spraySwathMeters)) / 60.0;

  // Summary Metrics
  final double canopyPct = totalPixels > 0 ? (canopyCount / totalPixels) * 100 : 0.0;
  final double meanVari = canopyCount > 0 ? (sumVari / canopyCount) : 0.0;
  final double stressPct = canopyCount > 0 ? (countStressed / canopyCount) * 100 : 0.0;

  String grade = 'เกรด C (ควรปรับปรุง)';
  if (meanVari >= 0.28) {
    grade = 'เกรด A+ (สมบูรณ์ยอดเยี่ยม)';
  } else if (meanVari >= 0.20) {
    grade = 'เกรด A (สมบูรณ์ดีมาก)';
  } else if (meanVari >= 0.12) {
    grade = 'เกรด B (ปานกลาง)';
  }

  final List<String> advice = [];
  advice.add('พื้นที่แปลงรวม: ${totalAreaSqMeters.toStringAsFixed(1)} ตร.ม. (${totalRai.floor()} ไร่ ${totalNgan.floor()} งาน ${totalSqWah.toStringAsFixed(1)} ตร.ว.)');
  advice.add('ตรวจนับต้นพืชสมบูรณ์ได้: ${detectedPlants.length} ต้น (ตรวจพบช่องว่างเว้าแหว่ง: $estimatedGaps จุด แนะนำเตรียมต้นกล้าปลูกซ่อม)');
  advice.add('อัตราพ่นสารชีวภัณฑ์: ${params.targetDosageLPerRai.toStringAsFixed(1)} ลิตร/ไร่ (ตั้งค่า Flow Rate หัวฉีดที่ ${flowRateLPerMin.toStringAsFixed(2)} ลิตร/นาที ปริมาตรสารรวม ${requiredChemicalLiters.toStringAsFixed(1)} ลิตร)');

  if (canopyPct > 65) {
    advice.add('สัดส่วนทรงพุ่ม ${canopyPct.toStringAsFixed(1)}% หนาแน่นดีเยี่ยม การสะสมตาดอกและคลอโรฟิลล์อยู่ในเกณฑ์สูง');
  } else {
    advice.add('สัดส่วนทรงพุ่ม ${canopyPct.toStringAsFixed(1)}% ค่อนข้างโปร่ง แนะนำเสริมปุ๋ยไนโตรเจนและฮอร์โมนกระตุ้นการแตกใบอ่อน');
  }

  if (stressPct > 8.0) {
    advice.add('ตรวจพบพื้นที่เครียดสะสม ${stressPct.toStringAsFixed(1)}% แนะนำตรวจสอบหัวสปริงเกอร์น้ำและรอยโรคเชื้อราไฟทอปธอร่า');
  } else {
    advice.add('ระดับความเครียดพืชต่ำ (${stressPct.toStringAsFixed(1)}%) การดูดซึมน้ำและแร่ธาตุสม่ำเสมอทั่วทั้งแปลง');
  }

  return AgriAnalysisResult(
    canopyCoveragePercent: canopyPct,
    meanVariIndex: meanVari,
    healthGrade: grade,
    stressPercent: stressPct,
    healthyPixelCount: countHealthy,
    moderatePixelCount: countModerate,
    stressedPixelCount: countStressed,
    nonVegetationPixelCount: countSoil,
    processedHeatmapBytes: heatmap,
    agronomicAdvice: advice,
    groundSampleDistanceCmPerPx: gsdCm,
    areaSqMeters: totalAreaSqMeters,
    areaRai: totalRai,
    areaNgan: totalNgan,
    areaSqWah: totalSqWah,
    plantCount: detectedPlants.length,
    plantLocations: detectedPlants,
    missingPlantCount: estimatedGaps,
    replantingSeedlings: estimatedGaps,
    sprayRateLitersPerRai: params.targetDosageLPerRai,
    flowRateLitersPerMin: flowRateLPerMin,
    requiredChemicalVolumeLiters: requiredChemicalLiters,
    spraySwathMeters: params.spraySwathMeters,
    energyConsumptionWhPerRai: energyWhPerRai,
    estimatedMissionTimeMinutes: flightDurationMin,
    timestamp: DateTime.now(),
  );
}

List<int> _mapSpectralColor(double val) {
  // Normalize -0.1 .. 0.55 to 0..1
  final double norm = ((val - (-0.1)) / (0.55 - (-0.1))).clamp(0.0, 1.0);

  if (norm < 0.2) {
    final double t = norm / 0.2;
    return [(180 + t * 50).round(), (30 + t * 60).round(), 20];
  } else if (norm < 0.45) {
    final double t = (norm - 0.2) / 0.25;
    return [(230 + t * 20).round(), (100 + t * 120).round(), 20];
  } else if (norm < 0.75) {
    final double t = (norm - 0.45) / 0.3;
    return [(250 - t * 180).round(), (220 + t * 30).round(), 40];
  } else {
    final double t = (norm - 0.75) / 0.25;
    return [(70 - t * 50).round(), (200 - t * 80).round(), (40 + t * 20).round()];
  }
}
