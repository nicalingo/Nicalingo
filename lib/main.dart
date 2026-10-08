import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_colors.dart';
import 'core/screens/splash_screen.dart'; 
// 1. AGREGAR ESTE IMPORT:
import 'core/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: 'https://xrisuvdfdnpzudbaqzbv.supabase.co',
    publishableKey: 'sb_publishable_zgaMHL76OEA5COJD3QleYg_s799Azre',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 2. AGREGAR ESTA LÍNEA PARA EL MODO OFFLINE/SYNC:
  SyncService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicaLingo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryYellow,
        scaffoldBackgroundColor: AppColors.primaryYellow,
        useMaterial3: true, 
      ),
      home: const SplashScreen(),
    );
  }
}