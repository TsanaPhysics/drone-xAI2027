import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'services/drone_udp_service.dart';
import 'services/agri_vision_service.dart';
import 'ui/screens/hud_cockpit_screen.dart';

void main() {
  print('DEBUG: >>> MAGIC DRONE DART MAIN CALLED <<<');
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: >>> WIDGETS BINDING INITIALIZED <<<');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DroneUdpService()),
        ChangeNotifierProvider(create: (_) => AgriVisionService()),
      ],
      child: const MagicDroneAgriApp(),
    ),
  );
}

class MagicDroneAgriApp extends StatelessWidget {
  const MagicDroneAgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAGIC Drone Agri-Vision Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HudCockpitScreen(),
    );
  }
}
