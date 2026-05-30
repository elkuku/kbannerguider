import 'package:flutter/material.dart';

import 'screens/banner_list_page.dart';

void main() {
  runApp(const KBannerGuiderApp());
}

class KBannerGuiderApp extends StatelessWidget {
  const KBannerGuiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBannerGuider',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: BannerListPage(),
    );
  }
}
