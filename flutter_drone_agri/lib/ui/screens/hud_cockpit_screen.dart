import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/drone_udp_service.dart';
import '../../services/agri_vision_service.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/telemetry_overlay.dart';
import '../widgets/split_cockpit_view.dart';
import 'agri_analysis_screen.dart';
import 'flight_plan_screen.dart';

class HudCockpitScreen extends StatefulWidget {
  const HudCockpitScreen({super.key});

  @override
  State<HudCockpitScreen> createState() => _HudCockpitScreenState();
}

class _HudCockpitScreenState extends State<HudCockpitScreen> {
  bool _isSplitScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DroneUdpService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final udpService = context.watch<DroneUdpService>();
    final agriService = context.watch<AgriVisionService>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Center Viewport: Either SplitCockpitView or Fullscreen FPV
            Positioned.fill(
              child: _isSplitScreen
                  ? SplitCockpitView(
                      udpService: udpService,
                      agriService: agriService,
                      onExpandFullscreen: () => setState(() => _isSplitScreen = false),
                    )
                  : Container(
                      color: Colors.black,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Simulated Video Canvas Feed
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.8,
                                colors: [
                                  const Color(0xFF1B4332).withOpacity(0.5),
                                  Colors.black,
                                ],
                              ),
                            ),
                          ),

                          // Comprehensive AR HUD Telemetry Overlay
                          TelemetryOverlay(
                            altitude: udpService.altitude,
                            speed: udpService.speed,
                            battery: udpService.batteryPercent,
                            rollAngle: udpService.rollAngle,
                            pitchAngle: udpService.pitchAngle,
                            headingDegrees: udpService.headingDegrees,
                            windSpeed: udpService.windSpeedMps,
                            isSprayActive: udpService.isSprayActive,
                            isLowBattery: udpService.isLowBatteryAlert,
                            isAltitudeBreach: udpService.isAltitudeLimitBreach,
                            isWindWarning: udpService.isWindWarning,
                          ),
                        ],
                      ),
                    ),
            ),

            // Top Status & Navigation Bar
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: udpService.isConnected ? AppTheme.neonGreen : AppTheme.neonRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        udpService.statusMessage,
                        style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Split Screen Mode Toggle
                      IconButton(
                        icon: Icon(_isSplitScreen ? Icons.view_agenda : Icons.view_column, size: 20),
                        tooltip: _isSplitScreen ? 'จอเดี่ยวเต็มจอ' : 'แบ่งหน้าจอคู่ (Split Screen)',
                        color: _isSplitScreen ? AppTheme.neonYellow : Colors.white70,
                        onPressed: () => setState(() => _isSplitScreen = !_isSplitScreen),
                      ),
                      const SizedBox(width: 6),

                      // Flight Plan Geofence Map
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map, size: 14),
                        label: const Text('แผนการบิน (Map)', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cardBg,
                          foregroundColor: AppTheme.neonCyan,
                          side: const BorderSide(color: AppTheme.neonCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FlightPlanScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Spectral & Agri-Vision Pro Analysis
                      ElevatedButton.icon(
                        icon: const Icon(Icons.psychology, size: 14),
                        label: const Text('วิเคราะห์แปลง (Agri)', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonGreen.withOpacity(0.2),
                          foregroundColor: AppTheme.neonGreen,
                          side: const BorderSide(color: AppTheme.neonGreen),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AgriAnalysisScreen()),
                          );
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Left Flight Control: Throttle / Yaw
            Positioned(
              left: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('THROTTLE / YAW', style: TextStyle(fontSize: 10, color: AppTheme.textDim, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  VirtualJoystick(
                    size: 150,
                    autoCenterY: false,
                    onPositionChanged: (offset) {
                      final int throt = ((-offset.dy + 1) * 127.5).round();
                      final int yaw = (128 + (offset.dx * 127)).round();
                      udpService.updateSticks(throttle: throt, yaw: yaw);
                    },
                  ),
                ],
              ),
            ),

            // Center Actions: Takeoff, Land, Emergency Cut, Spray Pump
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    label: 'TAKEOFF',
                    icon: Icons.flight_takeoff,
                    color: AppTheme.neonCyan,
                    onPressed: () => udpService.takeoff(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    label: 'LAND',
                    icon: Icons.flight_land,
                    color: AppTheme.neonYellow,
                    onPressed: () => udpService.land(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    label: udpService.isSprayActive ? 'SPRAY ON' : 'SPRAY OFF',
                    icon: Icons.water_drop,
                    color: udpService.isSprayActive ? AppTheme.neonGreen : AppTheme.textDim,
                    onPressed: () => udpService.toggleSpray(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    label: 'EMERGENCY',
                    icon: Icons.power_settings_new,
                    color: AppTheme.neonRed,
                    onPressed: () => udpService.emergencyStop(),
                  ),
                ],
              ),
            ),

            // Right Flight Control: Pitch / Roll
            Positioned(
              right: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('PITCH / ROLL', style: TextStyle(fontSize: 10, color: AppTheme.textDim, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  VirtualJoystick(
                    size: 150,
                    autoCenterY: true,
                    onPositionChanged: (offset) {
                      final int roll = (128 + (offset.dx * 127)).round();
                      final int pitch = (128 - (offset.dy * 127)).round();
                      udpService.updateSticks(roll: roll, pitch: pitch);
                    },
                  ),
                ],
              ),
            ),

            // Bottom Packet Hex Indicator
            Positioned(
              bottom: 4,
              left: 24,
              child: Text(
                'HEX: ${udpService.currentHexPacket}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.18),
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }
}
