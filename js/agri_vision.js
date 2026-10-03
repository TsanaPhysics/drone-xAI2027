/**
 * Precision Agriculture Drone Image Analysis Engine (Agri-Vision Pro)
 * Implements scientific visible-spectrum vegetation indices:
 * - VARI (Visual Atmospheric Resistance Index): (G - R) / (G + R - B)
 * - GLI (Green Leaf Index): (2G - R - B) / (2G + R + B)
 * - ExG (Excess Green Index): 2G - R - B
 * - Visible NDVI: (G - R) / (G + R + epsilon)
 * Provides False-Color Heatmaps, Canopy Mask, and Agronomic Health Scorecard.
 */

class AgriVisionEngine {
  constructor() {
    this.canvas = document.getElementById('analysisCanvas');
    this.ctx = this.canvas.getContext('2d');
    
    this.rawImageData = null;
    this.currentFilter = 'vari'; // 'rgb', 'vari', 'gli', 'exg', 'ndvi_vis', 'canopy_mask'
    this.sensitivityThreshold = 0.12;

    // Metrics Cache
    this.lastMetrics = {
      canopyCover: 0,
      meanVari: 0,
      healthGrade: 'N/A',
      stressPercent: 0,
      distribution: { healthy: 0, moderate: 0, stressed: 0, soil: 0 }
    };
  }

  /**
   * Load image from drone snapshot or uploaded image
   */
  processImageFromSource(sourceImageOrCanvas) {
    const w = this.canvas.width;
    const h = this.canvas.height;

    // Draw original image into analysis canvas
    this.ctx.drawImage(sourceImageOrCanvas, 0, 0, w, h);
    this.rawImageData = this.ctx.getImageData(0, 0, w, h);

    // Run spectral index calculation & render heatmap
    this.analyzeAndRender();
  }

  setFilter(filterName) {
    this.currentFilter = filterName;
    if (this.rawImageData) {
      this.analyzeAndRender();
    }
  }

  setThreshold(val) {
    this.sensitivityThreshold = parseFloat(val);
    document.getElementById('lblThreshold').innerText = this.sensitivityThreshold.toFixed(2);
    if (this.rawImageData) {
      this.analyzeAndRender();
    }
  }

  /**
   * Main Spectral Computation & Rendering Pipeline
   */
  analyzeAndRender() {
    if (!this.rawImageData) return;

    const w = this.canvas.width;
    const h = this.canvas.height;
    const src = this.rawImageData.data;
    const outImg = this.ctx.createImageData(w, h);
    const dst = outImg.data;

    const totalPixels = w * h;
    let canopyPixelCount = 0;
    let sumVari = 0;

    let countHealthy = 0;
    let countModerate = 0;
    let countStressed = 0;
    let countSoil = 0;

    for (let i = 0; i < src.length; i += 4) {
      const r = src[i];
      const g = src[i + 1];
      const b = src[i + 2];

      // Calculate Indices
      // 1. VARI = (G - R) / (G + R - B)
      const variDenom = (g + r - b);
      const vari = variDenom !== 0 ? (g - r) / variDenom : 0;
      const clampedVari = Math.max(-1.0, Math.min(1.0, vari));

      // 2. GLI = (2*G - R - B) / (2*G + R + B)
      const gliDenom = (2 * g + r + b);
      const gli = gliDenom !== 0 ? (2 * g - r - b) / gliDenom : 0;
      const clampedGli = Math.max(-1.0, Math.min(1.0, gli));

      // 3. ExG = 2*g - r - b (Normalized)
      const exg = (2 * g - r - b) / 255.0;

      // 4. Visible NDVI approx = (G - R) / (G + R + 0.001)
      const vNdvi = (g + r > 0) ? (g - r) / (g + r) : 0;

      // Canopy Classification based on sensitivity threshold
      const isCanopy = clampedVari >= this.sensitivityThreshold;
      if (isCanopy) {
        canopyPixelCount++;
        sumVari += clampedVari;

        if (clampedVari > 0.28) {
          countHealthy++;
        } else if (clampedVari > 0.15) {
          countModerate++;
        } else {
          countStressed++;
        }
      } else {
        countSoil++;
      }

      // Render based on selected filter
      if (this.currentFilter === 'rgb') {
        dst[i] = r;
        dst[i + 1] = g;
        dst[i + 2] = b;
        dst[i + 3] = 255;

      } else if (this.currentFilter === 'canopy_mask') {
        if (isCanopy) {
          dst[i] = 0;
          dst[i + 1] = 255;
          dst[i + 2] = 120;
          dst[i + 3] = 255;
        } else {
          // dimmed grayscale background for soil
          const gray = Math.round(0.299 * r + 0.587 * g + 0.114 * b) * 0.3;
          dst[i] = gray;
          dst[i + 1] = gray;
          dst[i + 2] = gray;
          dst[i + 3] = 255;
        }

      } else {
        // False-Color Heatmap for VARI / GLI / ExG / Visible NDVI
        let targetIndex = clampedVari;
        if (this.currentFilter === 'gli') targetIndex = clampedGli;
        if (this.currentFilter === 'exg') targetIndex = exg;
        if (this.currentFilter === 'ndvi_vis') targetIndex = vNdvi;

        const color = this.getSpectralHeatmapColor(targetIndex);
        dst[i] = color[0];
        dst[i + 1] = color[1];
        dst[i + 2] = color[2];
        dst[i + 3] = 255;
      }
    }

    // Put rendered pixels to canvas
    this.ctx.putImageData(outImg, 0, 0);

    // Compute Summary Statistics
    const canopyPct = (canopyPixelCount / totalPixels) * 100;
    const meanVari = canopyPixelCount > 0 ? (sumVari / canopyPixelCount) : 0;
    const stressPct = canopyPixelCount > 0 ? (countStressed / canopyPixelCount) * 100 : 0;

    let grade = 'เกรด C (ควรปรับปรุง)';
    if (meanVari >= 0.28) grade = 'เกรด A+ (สมบูรณ์เยี่ยม)';
    else if (meanVari >= 0.20) grade = 'เกรด A (สมบูรณ์ดีมาก)';
    else if (meanVari >= 0.12) grade = 'เกรด B (ปานกลาง)';

    this.lastMetrics = {
      canopyCover: canopyPct,
      meanVari: meanVari,
      healthGrade: grade,
      stressPercent: stressPct,
      distribution: {
        healthy: Math.round((countHealthy / totalPixels) * 100),
        moderate: Math.round((countModerate / totalPixels) * 100),
        stressed: Math.round((countStressed / totalPixels) * 100),
        soil: Math.round((countSoil / totalPixels) * 100)
      }
    };

    this.updateDashboardScorecard();
  }

  /**
   * Spectral Color Gradient Mapping:
   * Maps index [-0.2 to +0.6] to Red -> Amber -> Yellow -> Green -> Deep Emerald Green
   */
  getSpectralHeatmapColor(val) {
    // Normalize -0.1 .. 0.5 to 0.0 .. 1.0
    const norm = Math.max(0, Math.min(1, (val - (-0.1)) / (0.55 - (-0.1))));

    if (norm < 0.2) {
      // Red to Brown-Yellow (Severe Stress / Bare Soil)
      const t = norm / 0.2;
      return [180 + Math.round(t * 50), 30 + Math.round(t * 60), 20];
    } else if (norm < 0.45) {
      // Amber/Yellow (Moderate Stress / Sparse Canopy)
      const t = (norm - 0.2) / 0.25;
      return [230 + Math.round(t * 20), 100 + Math.round(t * 120), 20];
    } else if (norm < 0.75) {
      // Yellow-Green to Light Green (Healthy Crop)
      const t = (norm - 0.45) / 0.3;
      return [250 - Math.round(t * 180), 220 + Math.round(t * 30), 40];
    } else {
      // Lush Dark Emerald Green (Peak Chlorophyll & High Photosynthetic Activity)
      const t = (norm - 0.75) / 0.25;
      return [70 - Math.round(t * 50), 200 - Math.round(t * 80), 40 + Math.round(t * 20)];
    }
  }

  updateDashboardScorecard() {
    const m = this.lastMetrics;
    const canEl = document.getElementById('metricCanopy');
    const varEl = document.getElementById('metricMeanVari');
    const grdEl = document.getElementById('metricHealthGrade');
    const strEl = document.getElementById('metricStressArea');

    if (canEl) canEl.innerText = `${m.canopyCover.toFixed(1)}%`;
    if (varEl) varEl.innerText = `${m.meanVari.toFixed(2)}`;
    if (grdEl) grdEl.innerText = m.healthGrade;
    if (strEl) strEl.innerText = `${m.stressPercent.toFixed(1)}%`;

    // Update Health Breakdown Bar
    const bHealthy = document.getElementById('barHealthy');
    const bModerate = document.getElementById('barModerate');
    const bStressed = document.getElementById('barStressed');
    const bSoil = document.getElementById('barSoil');

    if (bHealthy) {
      bHealthy.style.width = `${m.distribution.healthy}%`;
      bHealthy.innerText = `${m.distribution.healthy}%`;
    }
    if (bModerate) {
      bModerate.style.width = `${m.distribution.moderate}%`;
      bModerate.innerText = `${m.distribution.moderate}%`;
    }
    if (bStressed) {
      bStressed.style.width = `${m.distribution.stressed}%`;
      bStressed.innerText = `${m.distribution.stressed}%`;
    }
    if (bSoil) {
      bSoil.style.width = `${m.distribution.soil}%`;
      bSoil.innerText = `${m.distribution.soil}%`;
    }

    // Dynamic Agricultural Advice
    this.updateAgronomicAdvice();
  }

  updateAgronomicAdvice() {
    const list = document.getElementById('recommendationList');
    if (!list) return;

    const m = this.lastMetrics;
    let items = [];

    if (m.distribution.healthy >= 60) {
      items.push(`<li>✅ <b>ทรงพุ่มสมบูรณ์สูง (${m.distribution.healthy}%):</b> ใบพืชมีปริมาณคลอโรฟิลล์หนาแน่น เหมาะแก่การเจริญเติบโตในระยะขยายผล</li>`);
    } else {
      items.push(`<li>⚠️ <b>ความหนาแน่นคลอโรฟิลล์ปานกลาง (${m.distribution.healthy}%):</b> แนะนำเสริมธาตุอาหารหลัก ไนโตรเจน (N) และแมกนีเซียม เพื่อกระตุ้นการสังเคราะห์แสง</li>`);
    }

    if (m.stressPercent > 8.0) {
      items.push(`<li>🚨 <b>จุดเตือนวิกฤตความเครียดพืช (${m.stressPercent.toFixed(1)}%):</b> พบใบเหลืองซีด/แคระแกร็นเป็นหย่อม แนะนำตรวจสอบการอุดตันของหัวสปริงเกลอร์/ระบบน้ำหยด หรือตรวจหาโรครากเน่าโคนเน่า</li>`);
    } else {
      items.push(`<li>💧 <b>การกระจายความชื้นสม่ำเสมอ:</b> ไม่พบจุดขาดน้ำรุนแรงในแปลง ควบคุมรอบการให้น้ำตามเวลาปกติ</li>`);
    }

    items.push(`<li>🛰️ <b>พิกัดการบินสำรวจ:</b> ความสูงบินสำรวจแนะนำ 10-15 เมตร เพื่อความละเอียดภาพ (GSD) 0.5 ซม./พิกเซล สำหรับโดรน MAGIC</li>`);

    list.innerHTML = items.join('');
  }

  exportCsv() {
    const m = this.lastMetrics;
    const now = new Date().toISOString();
    const csvContent = "data:text/csv;charset=utf-8," 
      + "Timestamp,CanopyCover_Percent,Mean_VARI_Index,Health_Grade,Stress_Percent,Healthy_Percent,Moderate_Percent,Soil_Percent\n"
      + `${now},${m.canopyCover.toFixed(2)},${m.meanVari.toFixed(3)},"${m.healthGrade}",${m.stressPercent.toFixed(2)},${m.distribution.healthy},${m.distribution.moderate},${m.distribution.soil}\n`;

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `drone_agri_analysis_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  exportHeatmapImage() {
    const link = document.createElement('a');
    link.download = `drone_vegetation_heatmap_${this.currentFilter}_${Date.now()}.png`;
    link.href = this.canvas.toDataURL('image/png');
    link.click();
  }
}

// Global agri vision engine instance
window.agriVision = new AgriVisionEngine();
