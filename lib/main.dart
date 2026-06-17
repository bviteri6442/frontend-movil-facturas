import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'config/dev_http_overrides.dart';
import 'screens/login_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/saldo_screen.dart';
import 'models/user.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    StripePlatform.instance = WebStripe.instance;
  }
  if (!kIsWeb && kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuntoVenta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/catalog': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! User) return const LoginScreen();
          final user = args;
          return CatalogScreen(user: user);
        },
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! User) return const LoginScreen();
          final user = args;
          return ProfileScreen(user: user);
        },
        '/saldo': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! User) return const LoginScreen();
          final user = args;
          return SaldoScreen(user: user);
        },
        '/history': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is! User) return const LoginScreen();
          final user = args;
          return HistoryScreen(user: user);
        },
      },
    );
  }
}

// La clase CatalogScreen real está en catalog_screen.dart