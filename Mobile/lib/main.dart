import 'dart:io';
import 'package:flutter/material.dart';

import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_colors.dart';

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
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(secondary: AppColors.gold),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
          iconTheme: IconThemeData(color: AppColors.primary),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
          titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.card,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.textDark,
          unselectedLabelColor: Colors.black38,
          indicatorColor: AppColors.primary,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      ),
      home: FutureBuilder<String>(
        future: SettingsService.loadBaseUrl(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          return MainNavigationScreen(initialBaseUrl: snapshot.data!);
        },
      ),
    );
  }
}