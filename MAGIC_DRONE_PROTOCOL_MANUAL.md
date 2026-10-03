# คู่มือสถาปัตยกรรมและโปรโตคอลโดรน MAGIC สำหรับแอปพลิเคชัน Flutter และการวิเคราะห์ภาพเกษตรแม่นยำ
**MAGIC Drone Controller & Precision Agriculture Image Analysis System**  
*จัดทำขึ้นสำหรับโครงการพัฒนาอากาศยานไร้คนขับเพื่อการเกษตรอัจฉริยะ (RBRU Agri-AI Series)*

---

## 1. ข้อมูลฮาร์ดแวร์และการเชื่อมต่อของโดรน MAGIC
จากลักษณะตัวเครื่องในภาพถ่าย:
- **รุ่นตัวเครื่อง:** โดรนขนาดเล็กพับขาได้ (Pocket / Mini Folding Quadcopter) สกรีนคำว่า **MAGIC** บอดี้สีแดง
- **ระบบขับเคลื่อน:** มอเตอร์ Coreless DC 3.7V - 7.4V ควบคุมความเร็วด้วยบอร์ด ESC ในตัว
- **กล้องหน้า (FPV Camera):** กล้อง HD/4K WiFi Camera ส่งภาพมุมมองบุคคลที่หนึ่ง (First Person View)
- **การเชื่อมต่อไร้สาย:** โดรนทำหน้าที่เป็น **Wi-Fi Access Point (SoftAP)** ไร้รหัสผ่าน (Open Network)
  - ชื่อ WiFi ประจำตัวมักตั้งชื่อในรูปแบบ: `WiFi-xxxxxx`, `MAGIC-xxxx`, `4K_xxxxxx`, `KY_xxxxxx` หรือ `HF-xxxxxx`
  - IP Address ของตัวโดรน (Default Gateway): ส่วนใหญ่กำหนดค่าตายตัวเป็น `192.168.1.1` (หรือบางล็อตชิปเซ็ตเป็น `192.168.4.1` หรือ `192.168.0.1`)
  - อุปกรณ์มือถือ/แท็บเล็ตที่เชื่อมต่อจะได้รับ IP เช่น `192.168.1.2` ผ่าน DHCP อัตโนมัติ

---

## 2. โครงสร้างโปรโตคอลคำสั่งบิน (UDP Flight Control Protocol)

โดรนประเภทนี้ใช้การส่งคำสั่งผ่านโปรโตคอล **UDP Datagram Socket** ไปยังพอร์ตควบคุม (Control Port) ที่ความถี่แนะนำ **20 Hz (ทุก 50 มิลลิวินาที)** โดยไม่เปิดค้างแบบ TCP เพื่อลดปัญหา Latency

### โครงสร้างแพ็กเก็ต 8 ไบต์ (Standard 8-Byte Frame):
```
[ 0x66, Roll, Pitch, Throttle, Yaw, Flags, Checksum, 0x99 ]
```

| ไบต์ที่ | ชื่อฟิลด์ | ช่วงค่า (Hex / Dec) | ค่าจุดกึ่งกลาง | คำอธิบายการควบคุม |
|:---:|:---|:---:|:---:|:---|
| **0** | **Header** | `0x66` (102) | - | รหัสเริ่มต้นแพ็กเก็ตคงที่ |
| **1** | **Roll** (เอียงซ้าย-ขวา) | `0x00` - `0xFF` | `0x80` (128) | `0x00` = เอียงซ้ายสุด, `0xFF` = เอียงขวาสุด |
| **2** | **Pitch** (เดินหน้า-ถอยหลัง) | `0x00` - `0xFF` | `0x80` (128) | `0x00` = ถอยหลังสุด, `0xFF` = เดินหน้าสุด |
| **3** | **Throttle** (ระดับความสูง) | `0x00` - `0xFF` | `0x80` (128) | `0x00` = กำลังต่ำสุด, `0xFF` = บินขึ้นสูงสุด |
| **4** | **Yaw** (หมุนหัวโดรน) | `0x00` - `0xFF` | `0x80` (128) | `0x00` = หมุนทวนเข็ม (ซ้าย), `0xFF` = หมุนตามเข็ม (ขวา) |
| **5** | **Command Flags** | `0x00` - `0x1F` | `0x00` | `0x01`: สั่ง Takeoff<br>`0x02`: สั่ง Land<br>`0x04`: Emergency Cut (ดับเครื่องทันที)<br>`0x10`: สั่ง Calibrate Gyro |
| **6** | **Checksum** | `0x00` - `0xFF` | คำนวณ XOR | `Checksum = Byte[1] ^ Byte[2] ^ Byte[3] ^ Byte[4] ^ Byte[5]` |
| **7** | **Footer** | `0x99` (153) | - | รหัสปิดท้ายแพ็กเก็ตคงที่ |

---

## 3. การรับภาพสตรีมวิดีโอจากโดรน (Camera Stream Endpoint)

กล้องของโดรน MAGIC สตรีมภาพในรูปแบบ **Motion JPEG (MJPEG)** ผ่าน HTTP หรือ RTSP:
1. **HTTP MJPEG Stream (พบบ่อยที่สุด):**
   - URL: `http://192.168.1.1:8080/?action=stream`
   - หรือ: `http://192.168.1.1:7070/stream`
   - หรือ: `http://192.168.1.1:8060/`
2. **Snapshot Frame Endpoint (ถ่ายภาพนิ่ง):**
   - URL: `http://192.168.1.1:8080/?action=snapshot`

---

## 4. สมการดัชนีพืชพรรณสำหรับวิเคราะห์ภาพถ่ายการเกษตร (Agri-Vision Spectral Indices)

เนื่องจากกล้องของโดรนเป็นเซนเซอร์แสงที่ตามองเห็น (RGB Sensor) ระบบจึงประมวลผลดัชนีพืชพรรณทางการเกษตรผ่าน Visible Vegetation Indices ที่ได้รับการยอมรับในระดับสากล:

### 1) Visual Atmospheric Resistance Index (VARI)
$$\text{VARI} = \frac{G - R}{G + R - B}$$
- **จุดเด่น:** ลดทอนการรบกวนของฝุ่นละอองในชั้นบรรยากาศและการสะท้อนของแดดได้ดีที่สุด เหมาะสำหรับการบินมุมสูง
- **การแปลผล:**
  - $\text{VARI} > 0.25$: พืชสมบูรณ์สูง คลอโรฟิลล์หนาแน่น
  - $0.10 \le \text{VARI} \le 0.25$: พืชระดับปานกลาง
  - $\text{VARI} < 0.10$: พืชเครียด ขาดน้ำ หรือเป็นบริเวณผิวดิน

### 2) Green Leaf Index (GLI)
$$\text{GLI} = \frac{2G - R - B}{2G + R + B}$$
- ช่วยแยกแยะระหว่างใบไม้สีเขียวออกจากเศษซากพืชแห้งและผิวดิน

### 3) Excess Green Index (ExG)
$$\text{ExG} = 2G - R - B$$
- ใช้สร้าง **Canopy Binary Mask** เพื่อตัดเฉพาะพื้นที่ทรงพุ่มพืชออกมาคำนวณสัดส่วนเปอร์เซ็นต์พื้นที่การปกคลุมดิน (Canopy Coverage Percentage)

---

## 5. วิธีเปิดทดสอบระบบ (How to Test)

### ช่องทางที่ 1: เปิดทดสอบ Interactive Simulator บน Browser ทันที (ผ่าน XAMPP)
1. เปิด Web Browser (Google Chrome, Edge หรือ Safari)
2. เข้าไปที่ URL:
   ```
   http://localhost/drone2027/
   ```
3. สามารถทดลอง:
   - บินโดรนด้วย **Dual Joystick เสมือน** (Mode 2)
   - ดูการคำนวณแพ็กเก็ต Hex UDP แบบ Real-time ที่ส่ง 20 ครั้ง/วินาที
   - กดปุ่ม **📸 CAPTURE & ANALYZE** เพื่อจับภาพแปลงเกษตร
   - สลับไปยังหน้า **🌱 AGRI-ANALYSIS** เพื่อดูแผนที่ความร้อน (False-Color Heatmap) และรายงานสุขภาพพืช
   - ส่งออกข้อมูลเป็น **CSV** หรือภาพ Heatmap ได้ทันที

### ช่องทางที่ 2: รันโปรเจกต์ Flutter บนมือถือ/แท็บเล็ต
โครงสร้างโค้ด Flutter พร้อมใช้งานถูกสร้างไว้ที่โฟลเดอร์:
`/Applications/XAMPP/xamppfiles/htdocs/drone2027/flutter_drone_agri/`

คำสั่งคอมไพล์และรัน:
```bash
cd /Applications/XAMPP/xamppfiles/htdocs/drone2027/flutter_drone_agri
flutter pub get
flutter run
```

---

## 6. เคล็ดลับการตรวจจับ IP / Port โดรนตัวจริง (Wireshark Sniffing Guide)
หากเปิดโดรนแล้วเชื่อมต่อ WiFi มือถือกับโดรน แต่ยังไม่มั่นใจ Port สามารถตรวจสอบได้ด้วยวิธี:
1. เชื่อมต่อคอมพิวเตอร์เข้ากับ WiFi ของโดรน MAGIC
2. เปิดโปรแกรม **Wireshark** แล้วเลือก Network Interface ที่เป็นการ์ด WiFi
3. ใส่ Filter: `udp` หรือ `http`
4. ใช้แอปเดิมของโดรนสั่งกดปุ่มทิศทาง จะเห็นแพ็กเก็ต UDP ขนาด 8 ไบต์ส่งไปยัง Port 7070 หรือ 8080 ทันที
