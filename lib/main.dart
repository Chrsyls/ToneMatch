import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_navigation.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cek apakah ada sesi login yang tersimpan di HP
  final prefs = await SharedPreferences.getInstance();
  final String? savedUid = prefs.getString('user_uid');
  final bool isLoggedIn = savedUid != null && savedUid.isNotEmpty;

  runApp(ToneMatchApp(isLoggedIn: isLoggedIn));
}

class ToneMatchApp extends StatelessWidget {
  final bool isLoggedIn;
  const ToneMatchApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToneMatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          primary: const Color(0xFFE91E63),
          secondary: const Color(0xFFFFC107),
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.josefinSans().fontFamily,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF4A2333),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ),
      // Jika sudah login langsung ke MainNavigation, jika belum ke AuthScreen
      home: isLoggedIn ? const MainNavigation() : const AuthScreen(),
    );
  }
}