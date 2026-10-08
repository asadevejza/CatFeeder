import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'theme/app_colors.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await NotificationService.init();
  runApp(const CatFeederApp());
}

class CatFeederApp extends StatelessWidget {
  const CatFeederApp({super.key});
  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.nunitoTextTheme();
    return MaterialApp(
      title: 'CatFeeder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.lavenderStrong,
          surface: AppColors.card,
        ),
        textTheme: baseText.apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: AppColors.textDark, centerTitle: false),
        cardTheme: CardThemeData(color: AppColors.card, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22)), side: BorderSide(color: AppColors.cardBorder))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w900))),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w800))),
        sliderTheme: const SliderThemeData(trackHeight: 6, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8)),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
      ),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget { const _AppRoot(); @override State<_AppRoot> createState()=>_AppRootState(); }
class _AppRootState extends State<_AppRoot> {
  bool? _isLoggedIn; String? _baseUrl;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {final url=await SettingsService.loadBaseUrl();await AuthService.loadFromStorage();if(!mounted)return;setState((){_baseUrl=url;_isLoggedIn=AuthService.isLoggedIn;});}
  void _handleAuthSuccess()=>setState(()=>_isLoggedIn=true);
  void _handleLogout()=>setState(()=>_isLoggedIn=false);
  Future<void> _handleBaseUrlChanged(String url) async {await SettingsService.saveBaseUrl(url);if(mounted)setState(()=>_baseUrl=url);}
  @override Widget build(BuildContext context){if(_isLoggedIn==null||_baseUrl==null)return const Scaffold(body:Center(child:CircularProgressIndicator(color:AppColors.primary)));if(!_isLoggedIn!)return AuthScreen(baseUrl:_baseUrl!,onSuccess:_handleAuthSuccess,onBaseUrlChanged:_handleBaseUrlChanged);return MainNavigationScreen(initialBaseUrl:_baseUrl!,onLogout:_handleLogout);}
}
