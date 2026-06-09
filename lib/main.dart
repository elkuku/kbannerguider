import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/banner_list_page.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const KBannerGuiderApp());
}

class KBannerGuiderApp extends StatefulWidget {
  const KBannerGuiderApp({super.key});

  @override
  State<KBannerGuiderApp> createState() => _KBannerGuiderAppState();
}

class _KBannerGuiderAppState extends State<KBannerGuiderApp> {
  static const _prefKey = 'dark_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? true;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeMode == ThemeMode.light;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: isDark
          ? const ColorScheme.dark(
              surface: Color(0xFF1C1C1C),
              onSurface: Colors.white,
              primary: Color(0xFF424242),
              onPrimary: Colors.white,
              secondary: Color(0xFF616161),
              onSecondary: Colors.white,
              inversePrimary: Color(0xFF303030),
            )
          : const ColorScheme.light(
              surface: Color(0xFFF5F5F5),
              onSurface: Colors.black,
              primary: Color(0xFF757575),
              onPrimary: Colors.white,
              secondary: Color(0xFF9E9E9E),
              onSecondary: Colors.black,
              inversePrimary: Color(0xFFE0E0E0),
            ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF212121) : const Color(0xFF424242),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? Colors.white : Colors.black87,
        unselectedLabelColor:
            isDark ? const Color(0xFF9E9E9E) : Colors.black45,
        indicatorColor: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBannerGuider',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: BannerListPage(
        authService: _authService,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
