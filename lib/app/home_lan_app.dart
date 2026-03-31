import 'package:flutter/material.dart';

import 'package:landscape/features/dashboard/home_dashboard_page.dart';

class HomeLanApp extends StatelessWidget {
  const HomeLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LANdscape',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7C66),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeDashboardPage(),
    );
  }
}
