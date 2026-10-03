/**
 * Main Controller & UI Event Dispatcher
 * Bridges Cockpit FPV, Precision Agri-Vision Studio, and Protocol Sniffer.
 */

document.addEventListener('DOMContentLoaded', () => {
  // Automatically load initial snapshot from farm simulator into analysis engine
  setTimeout(() => {
    captureSnapshotForAnalysis(false); // silent capture on boot
  }, 300);
});

// Tab Switcher
function switchTab(tabId) {
  const tabs = ['cockpit', 'analysis', 'protocol'];
  tabs.forEach(t => {
    const view = document.getElementById(`${t}View`);
    const btn = document.getElementById(`tab${capitalize(t)}Btn`);
    if (t === tabId) {
      if (view) view.classList.add('active');
      if (btn) btn.classList.add('active');
    } else {
      if (view) view.classList.remove('active');
      if (btn) btn.classList.remove('active');
    }
  });

  if (tabId === 'analysis') {
    // If opening analysis and no image processed yet, grab current frame
    if (!window.agriVision.rawImageData) {
      captureSnapshotForAnalysis(false);
    }
  }
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// Cockpit Flight Action Wrappers
function handleTakeoff() {
  window.droneEngine.takeoff();
}

function handleLand() {
  window.droneEngine.land();
}

function handleEmergencyStop() {
  window.droneEngine.emergencyCut();
}

function adjustTrim(axis, delta) {
  window.droneEngine.adjustTrim(axis, delta);
}

function calibrateGyro() {
  window.droneEngine.calibrateGyro();
}

function toggleHudGrid() {
  window.droneEngine.showGrid = !window.droneEngine.showGrid;
  window.droneEngine.logTelemetry(`HUD Guidelines: ${window.droneEngine.showGrid ? 'ENABLED' : 'DISABLED'}`);
}

function toggleRecording() {
  const btn = document.getElementById('recordBtn');
  window.droneEngine.isRecording = !window.droneEngine.isRecording;
  if (window.droneEngine.isRecording) {
    btn.innerText = '⏹️ STOP REC';
    btn.style.background = '#ef233c';
    btn.style.color = '#fff';
    window.droneEngine.logTelemetry('🔴 Aerial Video Recording started (4K FPV)');
  } else {
    btn.innerText = '🔴 REC FLIGHT';
    btn.style.background = '';
    btn.style.color = '';
    window.droneEngine.logTelemetry('💾 Aerial Video Recording saved to flight log storage.');
  }
}

// Video Source Switcher
function changeVideoSource(source) {
  const urlInput = document.getElementById('streamUrlInput');
  const connBtn = document.getElementById('streamConnectBtn');
  const fileInput = document.getElementById('fileUploadInput');

  urlInput.style.display = 'none';
  connBtn.style.display = 'none';

  if (source === 'custom_url') {
    urlInput.style.display = 'inline-block';
    connBtn.style.display = 'inline-block';
    window.droneEngine.videoMode = 'custom_url';
  } else if (source === 'webcam') {
    window.droneEngine.videoMode = 'webcam';
    navigator.mediaDevices.getUserMedia({ video: { width: 1280, height: 720 } })
      .then(stream => {
        window.droneEngine.videoElement.srcObject = stream;
        window.droneEngine.logTelemetry('📷 Live webcam/USB camera stream connected.');
      })
      .catch(err => {
        alert('ไม่สามารถเปิดกล้องเว็บแคมได้: ' + err.message);
        document.getElementById('videoSourceSelect').value = 'farm_sim';
        window.droneEngine.videoMode = 'farm_sim';
      });
  } else if (source === 'upload') {
    fileInput.click();
  } else {
    window.droneEngine.videoMode = 'farm_sim';
    window.droneEngine.logTelemetry('🌾 Switched to simulated high-res agricultural flight stream.');
  }
}

function connectCustomStream() {
  const url = document.getElementById('streamUrlInput').value.trim();
  if (!url) {
    alert('กรุณากรอก Stream URL ของโดรน MAGIC เช่น http://192.168.1.1:8080/?action=stream');
    return;
  }
  window.droneEngine.videoMode = 'custom_url';
  window.droneEngine.videoElement.src = url;
  window.droneEngine.logTelemetry(`🌐 Connecting to Drone MJPEG Video Stream at ${url}...`);
}

function handleFileUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = (e) => {
    const img = new Image();
    img.onload = () => {
      window.droneEngine.uploadedImage = img;
      window.droneEngine.videoMode = 'upload';
      window.droneEngine.logTelemetry(`📁 Loaded image: ${file.name} (${img.width}x${img.height})`);
      // auto feed to analysis
      window.agriVision.processImageFromSource(img);
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

// Snapshot & Precision Agri Analysis Trigger
function captureSnapshotForAnalysis(autoSwitchTab = true) {
  const fpv = document.getElementById('fpvCanvas');
  window.agriVision.processImageFromSource(fpv);

  const stamp = new Date().toLocaleTimeString('th-TH');
  const stampEl = document.getElementById('scanTimestamp');
  if (stampEl) stampEl.innerText = `SNAPSHOT CAPTURED AT ${stamp}`;

  window.droneEngine.logTelemetry(`📸 Snapshot frame captured. Precision agricultural spectral indices generated.`);

  if (autoSwitchTab) {
    switchTab('analysis');
  }
}

// Analysis Filter Selection
function setAnalysisFilter(filterName) {
  document.querySelectorAll('.filter-tab').forEach(btn => btn.classList.remove('active'));
  if (event && event.target) {
    event.target.classList.add('active');
  }
  window.agriVision.setFilter(filterName);
}

function updateSensitivity(val) {
  window.agriVision.setThreshold(val);
}

function exportAnalysisReport() {
  window.print();
}

function exportAnalysisImage() {
  window.agriVision.exportHeatmapImage();
}

function exportCsvData() {
  window.agriVision.exportCsv();
}

// Auto Protocol Scan Simulator
function runAutoProtocolScan() {
  const logEl = document.getElementById('scanResultLog');
  const ip = document.getElementById('scanSubnetInput').value.trim();
  const preset = document.getElementById('protocolPresetSelect').value;

  logEl.innerText = `[${new Date().toLocaleTimeString()}] Starting Auto-Discovery Probe on ${ip}...\n`;

  setTimeout(() => {
    logEl.innerText += `[+] Checking WiFi Gateway Ping: ${ip} (RTT: 4.2ms)\n`;
  }, 400);

  setTimeout(() => {
    logEl.innerText += `[+] Probing UDP Port 7070 (MAGIC / KY Toy Drone Protocol)...\n`;
  }, 900);

  setTimeout(() => {
    logEl.innerText += `[+] Drone handshake ACK received! Magic 8-Byte frame active.\n`;
    logEl.innerText += `[+] Video Stream Port detected: 8080 (MJPEG Stream Ready)\n`;
    logEl.innerText += `[SUCCESS] Protocol Locked: MAGIC 8-Byte (Header: 0x66, Tail: 0x99, Rate: 20Hz)\n`;
    logEl.scrollTop = logEl.scrollHeight;

    document.getElementById('currentDroneIp').innerText = `${ip}:7070`;
    document.getElementById('networkPulse').classList.add('connected');
  }, 1600);
}
