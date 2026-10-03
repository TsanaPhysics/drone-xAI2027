/**
 * MAGIC Drone Flight Engine & FPV HUD Simulation
 * Implements Mode 2 dual joysticks, 8-byte UDP packet encoder,
 * artificial horizon, and simulated agricultural aerial video feed.
 */

class MagicDroneEngine {
  constructor() {
    // Flight Control Values (-100 to +100 or 0 to 100)
    this.throttle = 0;   // 0 - 100% (Left Y)
    this.yaw = 0;        // -100 to +100% (Left X)
    this.pitch = 0;      // -100 to +100% (Right Y: + = forward, - = backward)
    this.roll = 0;       // -100 to +100% (Right X: + = right, - = left)
    
    // Trims
    this.trimPitch = 0;
    this.trimRoll = 0;

    // Flight Status
    this.isArmed = false;
    this.isFlying = false;
    this.battery = 87;
    this.altitude = 0.0; // meters
    this.speed = 0.0;    // m/s
    this.distance = 0.0; // meters
    this.flightTimeSec = 0;
    this.fps = 30.0;
    this.currentCmdFlag = 0x00; // 0x01: Takeoff, 0x02: Land, 0x04: Emergency

    // Canvas References
    this.fpvCanvas = document.getElementById('fpvCanvas');
    this.fpvCtx = this.fpvCanvas.getContext('2d');
    this.hudCanvas = document.getElementById('hudOverlayCanvas');
    this.hudCtx = this.hudCanvas.getContext('2d');

    // Video Source Mode: 'farm_sim', 'webcam', 'custom_url', 'upload'
    this.videoMode = 'farm_sim';
    this.videoElement = document.createElement('video');
    this.videoElement.autoplay = true;
    this.videoElement.muted = true;
    this.videoElement.playsInline = true;
    this.uploadedImage = null;

    // Farm Simulation Aerial Coordinates
    this.droneWorldX = 400;
    this.droneWorldY = 300;
    this.droneHeading = 0; // degrees

    // Grid Overlay Setting
    this.showGrid = true;

    // Recording State
    this.isRecording = false;

    // Initialize Subsystems
    this.initJoysticks();
    this.initFlightLoop();
    this.initFarmSimulator();
  }

  // ==========================================
  // JOYSTICK CONTROLLER (Touch & Mouse Support)
  // ==========================================
  initJoysticks() {
    this.setupStick('leftJoyBound', 'leftJoyThumb', (x, y) => {
      // Left Stick: X = Yaw (-100 to 100), Y = Throttle (0 to 100)
      this.yaw = Math.round(x * 100);
      // Map y (-1 to 1) where top (-1) is 100% throttle, bottom (1) is 0%
      let rawThrot = Math.round((-y + 1) * 50);
      this.throttle = Math.max(0, Math.min(100, rawThrot));

      document.getElementById('valThrottle').innerText = `${this.throttle}%`;
      document.getElementById('valYaw').innerText = `${this.yaw > 0 ? '+' : ''}${this.yaw}°/s`;
      this.updateHexPacket();
    }, false); // don't snap Y to center for throttle if user wants altitude hold or snap

    this.setupStick('rightJoyBound', 'rightJoyThumb', (x, y) => {
      // Right Stick: X = Roll (-100 to 100), Y = Pitch (-100 to 100)
      this.roll = Math.round(x * 100);
      this.pitch = Math.round(-y * 100); // invert so up is positive pitch (forward)

      document.getElementById('valPitch').innerText = `${this.pitch > 0 ? '+' : ''}${this.pitch}%`;
      document.getElementById('valRoll').innerText = `${this.roll > 0 ? '+' : ''}${this.roll}%`;
      this.updateHexPacket();
    }, true); // auto-center right stick
  }

  setupStick(boundId, thumbId, onUpdate, autoCenterY = true) {
    const bound = document.getElementById(boundId);
    const thumb = document.getElementById(thumbId);
    let active = false;
    const maxRadius = (bound.clientWidth / 2) - (thumb.clientWidth / 2);

    const handlePointerDown = (e) => {
      active = true;
      bound.setPointerCapture(e.pointerId);
      updatePosition(e);
    };

    const handlePointerMove = (e) => {
      if (!active) return;
      updatePosition(e);
    };

    const handlePointerUp = (e) => {
      if (!active) return;
      active = false;
      bound.releasePointerCapture(e.pointerId);

      // Reset Thumb position
      if (autoCenterY) {
        thumb.style.transform = `translate(-50%, -50%)`;
        onUpdate(0, 0);
      } else {
        // Snap X to center, keep Y where it was released
        const curY = parseFloat(thumb.dataset.curY || '0');
        thumb.style.transform = `translate(calc(-50% + 0px), calc(-50% + ${curY}px))`;
        onUpdate(0, curY / maxRadius);
      }
    };

    const updatePosition = (e) => {
      const rect = bound.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      let dx = e.clientX - centerX;
      let dy = e.clientY - centerY;

      const dist = Math.hypot(dx, dy);
      if (dist > maxRadius) {
        dx = (dx / dist) * maxRadius;
        dy = (dy / dist) * maxRadius;
      }

      thumb.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
      thumb.dataset.curY = dy;

      const normX = dx / maxRadius;
      const normY = dy / maxRadius;
      onUpdate(normX, normY);
    };

    bound.addEventListener('pointerdown', handlePointerDown);
    bound.addEventListener('pointermove', handlePointerMove);
    bound.addEventListener('pointerup', handlePointerUp);
    bound.addEventListener('pointercancel', handlePointerUp);
  }

  // ==========================================
  // MAGIC DRONE 8-BYTE PACKET ENCODER
  // ==========================================
  /**
   * Packet Structure:
   * Byte 0: 0x66 (Header)
   * Byte 1: Roll (0x00 - 0xFF, center 0x80)
   * Byte 2: Pitch (0x00 - 0xFF, center 0x80)
   * Byte 3: Throttle (0x00 - 0xFF, 0x80 is mid/hover)
   * Byte 4: Yaw (0x00 - 0xFF, center 0x80)
   * Byte 5: Command Flag (0x00 normal, 0x01 takeoff, 0x02 land, 0x04 emergency)
   * Byte 6: Checksum = Byte 1 ^ Byte 2 ^ Byte 3 ^ Byte 4 ^ Byte 5
   * Byte 7: 0x99 (Footer)
   */
  generateUdpPacket() {
    // Map -100..100 to 0x00..0xFF (midpoint 128 = 0x80)
    const mapToByte = (val) => Math.max(0, Math.min(255, Math.round(128 + (val * 1.27))));
    const mapThrot = (val) => Math.max(0, Math.min(255, Math.round(val * 2.55)));

    const bRoll = mapToByte(this.roll + this.trimRoll);
    const bPitch = mapToByte(this.pitch + this.trimPitch);
    const bThrottle = mapThrot(this.throttle);
    const bYaw = mapToByte(this.yaw);
    const bFlags = this.currentCmdFlag;

    const bChecksum = (bRoll ^ bPitch ^ bThrottle ^ bYaw ^ bFlags) & 0xFF;

    return [0x66, bRoll, bPitch, bThrottle, bYaw, bFlags, bChecksum, 0x99];
  }

  updateHexPacket() {
    const packet = this.generateUdpPacket();
    const hexStr = packet.map(b => b.toString(16).padStart(2, '0').toUpperCase()).join(' ');
    const hexElem = document.getElementById('liveHexPacket');
    if (hexElem) hexElem.innerText = hexStr;
  }

  // ==========================================
  // FLIGHT CONTROLS & COMMANDS
  // ==========================================
  takeoff() {
    this.isArmed = true;
    this.isFlying = true;
    this.throttle = 50;
    this.altitude = 1.2;
    this.currentCmdFlag = 0x01; // Takeoff bit
    this.updateFlightStatus('FLYING / IN AIR (AUTO-HOVER)');
    this.logTelemetry('🚀 Takeoff command executed. Altitude auto-hover engaged.');
    this.updateHexPacket();

    setTimeout(() => {
      this.currentCmdFlag = 0x00; // Reset flag after 1.5s
      this.updateHexPacket();
    }, 1500);
  }

  land() {
    this.currentCmdFlag = 0x02; // Land bit
    this.updateFlightStatus('AUTO-LANDING...');
    this.logTelemetry('🛬 Landing command executed. Descending gradually...');
    this.updateHexPacket();

    const descendInterval = setInterval(() => {
      if (this.altitude > 0.1) {
        this.altitude = Math.max(0, this.altitude - 0.3);
        this.throttle = Math.max(0, this.throttle - 5);
      } else {
        clearInterval(descendInterval);
        this.altitude = 0.0;
        this.throttle = 0;
        this.isFlying = false;
        this.currentCmdFlag = 0x00;
        this.updateFlightStatus('STANDBY / LANDED');
        this.logTelemetry('✅ Drone safely landed. Motors disarmed.');
        this.updateHexPacket();
      }
    }, 200);
  }

  emergencyCut() {
    this.throttle = 0;
    this.pitch = 0;
    this.roll = 0;
    this.yaw = 0;
    this.isFlying = false;
    this.isArmed = false;
    this.altitude = 0.0;
    this.currentCmdFlag = 0x04; // Emergency kill
    this.updateFlightStatus('EMERGENCY CUT! MOTORS STOPPED');
    this.logTelemetry('🛑 EMERGENCY CUT OFF ACTIVATED! All motor PWM killed.');
    this.updateHexPacket();

    setTimeout(() => {
      this.currentCmdFlag = 0x00;
      this.updateHexPacket();
    }, 1000);
  }

  calibrateGyro() {
    this.logTelemetry('⚖️ Gyroscope calibration packet sent. Keep drone on flat level surface...');
    this.trimPitch = 0;
    this.trimRoll = 0;
    document.getElementById('trimP').innerText = '0';
    document.getElementById('trimR').innerText = '0';
    setTimeout(() => {
      this.logTelemetry('✅ IMU 6-Axis Gyro calibration complete. Offsets zeroed.');
    }, 1200);
  }

  adjustTrim(axis, delta) {
    if (axis === 'pitch') {
      this.trimPitch = Math.max(-20, Math.min(20, this.trimPitch + delta));
      document.getElementById('trimP').innerText = this.trimPitch;
    } else {
      this.trimRoll = Math.max(-20, Math.min(20, this.trimRoll + delta));
      document.getElementById('trimR').innerText = this.trimRoll;
    }
    this.updateHexPacket();
    this.logTelemetry(`Trim updated: P=${this.trimPitch}, R=${this.trimRoll}`);
  }

  updateFlightStatus(text) {
    const el = document.getElementById('flightStateText');
    if (el) el.innerText = text;
  }

  logTelemetry(msg) {
    const ticker = document.getElementById('logTicker');
    if (ticker) {
      const time = new Date().toTimeString().split(' ')[0];
      ticker.innerText = `[${time}] ${msg}`;
    }
  }

  // ==========================================
  // REAL-TIME SIMULATED FARM AERIAL VIEW
  // ==========================================
  initFarmSimulator() {
    // Generate Procedural High-Resolution Precision Farm Map
    this.farmMapCanvas = document.createElement('canvas');
    this.farmMapCanvas.width = 2400;
    this.farmMapCanvas.height = 1800;
    const mctx = this.farmMapCanvas.getContext('2d');

    // 1. Base Soil Background (Rich loam / brown-olive)
    mctx.fillStyle = '#4a4031';
    mctx.fillRect(0, 0, 2400, 1800);

    // 2. Agricultural Plots & Dirt Roads
    mctx.fillStyle = '#6c584c';
    mctx.fillRect(100, 100, 2200, 1600);

    // Roads / Tractor Paths
    mctx.strokeStyle = '#a98467';
    mctx.lineWidth = 36;
    mctx.beginPath();
    mctx.moveTo(100, 900);
    mctx.lineTo(2300, 900);
    mctx.moveTo(1200, 100);
    mctx.lineTo(1200, 1700);
    mctx.stroke();

    // 3. Orchard Tree Canopies (Pomelo / Durian / Fruit Tree Clusters)
    // Draw 4 distinct agricultural blocks
    const drawPlantationBlock = (startX, startY, rows, cols, spacingX, spacingY, healthyColor, stressedColor, stressRatio) => {
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const px = startX + c * spacingX + (Math.random() * 8 - 4);
          const py = startY + r * spacingY + (Math.random() * 8 - 4);
          const radius = 22 + Math.random() * 6;

          const isStressed = Math.random() < stressRatio;
          const leafColor = isStressed ? stressedColor : healthyColor;

          // Shadow
          mctx.beginPath();
          mctx.arc(px + 4, py + 4, radius, 0, Math.PI * 2);
          mctx.fillStyle = 'rgba(20, 15, 10, 0.4)';
          mctx.fill();

          // Outer Foliage
          mctx.beginPath();
          mctx.arc(px, py, radius, 0, Math.PI * 2);
          mctx.fillStyle = leafColor;
          mctx.fill();

          // Crown highlight
          mctx.beginPath();
          mctx.arc(px - 3, py - 3, radius * 0.6, 0, Math.PI * 2);
          mctx.fillStyle = isStressed ? '#e9c46a' : '#55a630';
          mctx.fill();
        }
      }
    };

    // Block 1: Highly Healthy Durian Orchard (Top-Left)
    drawPlantationBlock(180, 180, 14, 18, 52, 48, '#2d6a4f', '#d4a373', 0.05);

    // Block 2: Moderate Citrus Orchard with water stress patch (Top-Right)
    drawPlantationBlock(1300, 180, 14, 18, 52, 48, '#40916c', '#c1121f', 0.25);

    // Block 3: Cassava / Maize Dense Field (Bottom-Left)
    drawPlantationBlock(180, 980, 14, 18, 52, 48, '#1b4332', '#e76f51', 0.08);

    // Block 4: Young Sapling Field with exposed soil (Bottom-Right)
    drawPlantationBlock(1300, 980, 14, 18, 52, 48, '#52b788', '#bc6c25', 0.15);
  }

  // ==========================================
  // MAIN FLIGHT & RENDERING LOOP (60 FPS)
  // ==========================================
  initFlightLoop() {
    let lastTime = performance.now();
    let packetTimer = 0;

    const loop = (now) => {
      const dt = (now - lastTime) / 1000;
      lastTime = now;

      // Update Simulated Physics
      if (this.isFlying) {
        // Vertical climb/descend
        const vertVel = (this.throttle - 50) * 0.1;
        this.altitude = Math.max(0.5, Math.min(120, this.altitude + vertVel * dt));

        // Horizontal velocity from Pitch and Roll
        const forwardVel = (this.pitch / 100) * 8.0; // max 8 m/s
        const strafeVel = (this.roll / 100) * 6.0;

        // Yaw rate
        this.droneHeading += (this.yaw / 100) * 45 * dt;

        // Position update
        const rad = (this.droneHeading * Math.PI) / 180;
        this.droneWorldX += (Math.sin(rad) * forwardVel + Math.cos(rad) * strafeVel) * dt * 25;
        this.droneWorldY -= (Math.cos(rad) * forwardVel - Math.sin(rad) * strafeVel) * dt * 25;

        // Bound world coordinate
        this.droneWorldX = Math.max(400, Math.min(2000, this.droneWorldX));
        this.droneWorldY = Math.max(300, Math.min(1500, this.droneWorldY));

        this.speed = Math.hypot(forwardVel, strafeVel);
        this.distance += this.speed * dt;
        this.flightTimeSec += dt;

        // Battery slow drain
        this.battery = Math.max(5, this.battery - (dt * 0.02));
      }

      // 20Hz Drone UDP Heartbeat
      packetTimer += dt;
      if (packetTimer >= 0.05) { // 20 times per second
        packetTimer = 0;
        this.updateHexPacket();
      }

      // Render Video & HUD Overlay
      this.renderVideoFeed();
      this.renderHudOverlay();
      this.updateHudTelemetryElements();

      requestAnimationFrame(loop);
    };

    requestAnimationFrame(loop);
  }

  renderVideoFeed() {
    const w = this.fpvCanvas.width;
    const h = this.fpvCanvas.height;

    if (this.videoMode === 'farm_sim') {
      // Crop area from high-res farm map based on drone position & altitude
      const zoomFactor = Math.max(0.6, 2.5 - (this.altitude * 0.06));
      const cropW = w / zoomFactor;
      const cropH = h / zoomFactor;

      const sx = Math.max(0, Math.min(this.farmMapCanvas.width - cropW, this.droneWorldX - cropW / 2));
      const sy = Math.max(0, Math.min(this.farmMapCanvas.height - cropH, this.droneWorldY - cropH / 2));

      this.fpvCtx.save();
      // Apply slight camera gimbal vibration when flying
      if (this.isFlying) {
        const shakeX = (Math.random() - 0.5) * 1.5;
        const shakeY = (Math.random() - 0.5) * 1.5;
        this.fpvCtx.translate(shakeX, shakeY);
      }

      this.fpvCtx.drawImage(this.farmMapCanvas, sx, sy, cropW, cropH, 0, 0, w, h);
      this.fpvCtx.restore();

    } else if (this.videoMode === 'webcam' || this.videoMode === 'custom_url') {
      if (this.videoElement.readyState >= 2) {
        this.fpvCtx.drawImage(this.videoElement, 0, 0, w, h);
      }
    } else if (this.videoMode === 'upload' && this.uploadedImage) {
      this.fpvCtx.drawImage(this.uploadedImage, 0, 0, w, h);
    }
  }

  renderHudOverlay() {
    const w = this.hudCanvas.width;
    const h = this.hudCanvas.height;
    const ctx = this.hudCtx;
    ctx.clearRect(0, 0, w, h);

    const cx = w / 2;
    const cy = h / 2;

    // 1. Grid Guidelines (if enabled)
    if (this.showGrid) {
      ctx.strokeStyle = 'rgba(0, 240, 255, 0.12)';
      ctx.lineWidth = 1;

      // Rule of thirds
      ctx.beginPath();
      ctx.moveTo(w / 3, 0); ctx.lineTo(w / 3, h);
      ctx.moveTo((w * 2) / 3, 0); ctx.lineTo((w * 2) / 3, h);
      ctx.moveTo(0, h / 3); ctx.lineTo(w, h / 3);
      ctx.moveTo(0, (h * 2) / 3); ctx.lineTo(w, (h * 2) / 3);
      ctx.stroke();
    }

    // 2. Artificial Horizon & Pitch Ladder
    ctx.save();
    ctx.translate(cx, cy);

    // Roll angle in radians
    const rollRad = (-this.roll * 0.25 * Math.PI) / 180;
    const pitchOffset = this.pitch * 0.8;

    ctx.rotate(rollRad);

    // Horizon line
    ctx.strokeStyle = '#00f0ff';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-120, pitchOffset);
    ctx.lineTo(-40, pitchOffset);
    ctx.moveTo(40, pitchOffset);
    ctx.lineTo(120, pitchOffset);
    ctx.stroke();

    // Pitch ladder bars (+10°, -10°)
    ctx.strokeStyle = 'rgba(0, 240, 255, 0.4)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    // +10
    ctx.moveTo(-50, pitchOffset - 30); ctx.lineTo(50, pitchOffset - 30);
    // -10
    ctx.moveTo(-50, pitchOffset + 30); ctx.lineTo(50, pitchOffset + 30);
    ctx.stroke();

    ctx.restore();

    // 3. Aircraft Reticle / Central Crosshair
    ctx.strokeStyle = '#00ff88';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(cx, cy, 18, 0, Math.PI * 2);
    ctx.moveTo(cx - 30, cy); ctx.lineTo(cx - 18, cy);
    ctx.moveTo(cx + 18, cy); ctx.lineTo(cx + 30, cy);
    ctx.moveTo(cx, cy - 30); ctx.lineTo(cx, cy - 18);
    ctx.moveTo(cx, cy + 18); ctx.lineTo(cx, cy + 30);
    ctx.stroke();

    // Center dot
    ctx.fillStyle = '#00ff88';
    ctx.beginPath();
    ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
    ctx.fill();

    // 4. Compass Heading Tape (Top Center)
    ctx.fillStyle = 'rgba(10, 15, 28, 0.7)';
    ctx.fillRect(cx - 100, 60, 200, 24);
    ctx.strokeStyle = 'rgba(0, 240, 255, 0.3)';
    ctx.strokeRect(cx - 100, 60, 200, 24);

    ctx.fillStyle = '#00f0ff';
    ctx.font = '12px Orbitron, sans-serif';
    ctx.textAlign = 'center';
    const hdg = Math.round((this.droneHeading % 360 + 360) % 360);
    ctx.fillText(`HDG: ${hdg.toString().padStart(3, '0')}°`, cx, 76);

    // 5. Recording indicator if active
    if (this.isRecording) {
      ctx.fillStyle = '#ef233c';
      ctx.beginPath();
      ctx.arc(40, 50, 8, 0, Math.PI * 2);
      ctx.fill();
      ctx.font = '12px Orbitron, sans-serif';
      ctx.fillStyle = '#fff';
      ctx.textAlign = 'left';
      ctx.fillText('REC 4K FPV', 56, 54);
    }
  }

  updateHudTelemetryElements() {
    const altEl = document.getElementById('hudAlt');
    const spdEl = document.getElementById('hudSpeed');
    const dstEl = document.getElementById('hudDist');
    const rolEl = document.getElementById('hudRoll');
    const pitEl = document.getElementById('hudPitch');
    const fpsEl = document.getElementById('hudFps');
    const battEl = document.getElementById('droneBatt');

    if (altEl) altEl.innerText = `${this.altitude.toFixed(1)} m`;
    if (spdEl) spdEl.innerText = `${this.speed.toFixed(1)} m/s`;
    if (dstEl) dstEl.innerText = `${this.distance.toFixed(0)} m`;
    if (rolEl) rolEl.innerText = `${this.roll > 0 ? '+' : ''}${this.roll}°`;
    if (pitEl) pitEl.innerText = `${this.pitch > 0 ? '+' : ''}${this.pitch}°`;
    if (fpsEl) fpsEl.innerText = `${(30 + (Math.random() * 0.4 - 0.2)).toFixed(1)}`;
    if (battEl) battEl.innerText = `${this.battery.toFixed(0)}% (3.82V)`;
  }
}

// Global drone engine instance
window.droneEngine = new MagicDroneEngine();
