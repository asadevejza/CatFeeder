import 'dart:io';
import 'package:flutter/material.dart';

import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await NotificationService.init();
  runApp(const CatFeederApp());
}

// ================= APP + TEMA =================
class CatFeederApp extends StatelessWidget {
  const CatFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatFeeder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2B3C),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C)),
          iconTheme: IconThemeData(color: Colors.lightBlue),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
      ),
      home: FutureBuilder<String>(
        future: SettingsService.loadBaseUrl(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFFF7FAFC),
              body: Center(child: CircularProgressIndicator(color: Colors.lightBlue)),
            );
          }
          return MainNavigationScreen(initialBaseUrl: snapshot.data!);
        },
      ),
    );
  }
}