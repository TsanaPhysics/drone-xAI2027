# drone-xAI2027

**MAGIC Drone Agri-Vision Pro | ระบบควบคุมโดรนและวิเคราะห์ภาพถ่ายการเกษตรอัจฉริยะ (Edge AI & AR Cockpit)**

โครงการวิจัยและพัฒนาระบบควบคุมอากาศยานไร้คนขับ (UAV / Agricultural Drone) สำหรับการเกษตรแม่นยำสูง (Precision Agriculture) โดย ผศ.ดร.ชีวะ ทัศนา และคณะ สาขาวิชาฟิสิกส์ คณะวิทยาศาสตร์และเทคโนโลยี มหาวิทยาลัยราชภัฏรำไพพรรณี

---

## 🌟 ฟีเจอร์หลัก (Key Features)

### 1. Flutter Mobile Application (`flutter_drone_agri`)
- **FPV Split-Screen Cockpit:** โหมดจอคู่ รองรับการแสดงผลภาพสด FPV ควบคู่กับแผนที่ความร้อนแปลงพืช (NDVI/VARI Heatmap) หรือแผนผังเส้นทางบินสำรวจ
- **AR HUD Telemetry Overlay:** แสดงเส้นขอบฟ้าจำลอง (Pitch Ladder & Artificial Horizon), เข็มทิศแบบ Heading Tape, พิกัดกริดแปลงพืช (Spatial Ground Grid) และเป้าเล็งเรดาร์แบบ Real-Time
- **Interactive Flight Plan & Geofencing:** วาดกำหนดพิกัดแปลงเกษตร (Polygon Boundary) พร้อมระบบคำนวณเส้นทางการบินสำรวจแบบอัตโนมัติ (Lawnmower Survey Grid)
- **Haptic & Visual Safety System:** ระบบสั่นเตือนและแถบเตือนสถานะความปลอดภัยเมื่อแบตเตอรี่ต่ำกว่า 20%, ลมกรรโชกแรงเกินกำหนด หรือใกล้เพดานบินสูงสุด

### 2. Edge AI Agri-Vision & Quantitative Telemetry
- **Ground Sample Distance (GSD):** คำนวณความละเอียดพื้นที่จริง (cm/pixel) ตามระดับความสูงและทางยาวโฟกัส
- **Thai Land Units Conversion:** แปลงขนาดพื้นที่แปลงเพาะปลูกเป็นหน่วยวัดที่ดินไทย (ไร่ - งาน - ตารางวา)
- **Durian Tree & Plant Counter:** ตรวจนับจำนวนต้นไม้และทรงพุ่มด้วย Local Maxima Peak Detection พร้อมระบุตำแหน่ง Centroid และขนาดรัศมีทรงพุ่ม
- **Missing Plant Gap Analysis:** ค้นหาช่องว่างและจุดที่ต้นกล้าตายหรือไม่เจริญเติบโตเพื่อการปลูกซ่อมแซม
- **Precision Spray & Flow Calculation:** คำนวณอัตราการฉีดพ่นสารเคมี/ชีวภัณฑ์ (ลิตร/นาที และ ลิตร/ไร่) สัมพันธ์กับ Ground Speed
- **Energy Efficiency:** คำนวณอัตราสิ้นเปลืองพลังงานแบตเตอรี่ (Watt-hour / ไร่)

### 3. RBRU Academic Manual (XeLaTeX)
- เอกสารคู่มือวิชาการฉบับสมบูรณ์ 43 หน้า รหัสมาตรฐานมหาวิทยาลัยราชภัฏรำไพพรรณี (RBRU)
- ไฟล์คู่มือ: `MAGIC_DRONE_AGRI_MANUAL.pdf`
- ซอร์สโค้ด LaTeX: ไดเรกทอรี `manual_rbru_latex/`

---

## 🚀 โครงสร้างโครงการ (Project Structure)

```
drone-xAI2027/
├── assets/                       # ไอคอนและกราฟิกของระบบ
├── css/                          # สไตล์ชีท Web Portal Glassmorphism
├── js/                           # JavaScript ควบคุม Web Portal
├── flutter_drone_agri/           # ซอร์สโค้ด Flutter Application (Android / iOS)
│   ├── lib/
│   │   ├── models/               # Data Models (Telemetry, AgriAnalysis, Waypoint)
│   │   ├── services/             # Drone UDP Service, Agri-Vision Service
│   │   └── ui/                   # Cockpit HUD, Flight Planner, Agri-Analysis
├── manual_rbru_latex/            # ซอร์สโค้ดคู่มือวิชาการ XeLaTeX ตามระเบียบ RBRU
├── MAGIC_DRONE_AGRI_MANUAL.pdf   # เอกสารคู่มือวิชาการฉบับสมบูรณ์ (43 หน้า)
├── index.html                    # หน้าจอ Web Cockpit & Telemetry Portal
└── README.md                     # เอกสารแนะนำโครงการ
```

---

## 📖 การติดตั้งและการรัน Flutter App

```bash
cd flutter_drone_agri
flutter pub get
flutter run
```

---

© 2026 สาขาวิชาฟิสิกส์ คณะวิทยาศาสตร์และเทคโนโลยี มหาวิทยาลัยราชภัฏรำไพพรรณี
ผู้พัฒนาและหัวหน้าโครงการ: ผศ.ดร.ชีวะ ทัศนา (Asst. Prof. Dr. Chewa Thassana)
