import 'package:flutter/material.dart';

import 'screens/banner_list_page.dart';
import 'services/auth_service.dart';
import 'services/drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.initialize();
  runApp(KBannerGuiderApp(authService: authService));
}

class KBannerGuiderApp extends StatelessWidget {
  const KBannerGuiderApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBannerGuider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 100, 100, 100),
        ),
        useMaterial3: true,
      ),
      home: BannerListPage(
        authService: authService,
        driveService: DriveService(),
      ),
    );
  }
}
