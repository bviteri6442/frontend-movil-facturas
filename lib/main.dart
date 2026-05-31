import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/saldo_screen.dart';
import 'models/user.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuntoVenta',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/catalog': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as User;
          return CatalogScreen(user: user);
        },
        '/register': (context) => RegisterScreen(),
        '/profile': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as User;
          return ProfileScreen(user: user);
        },
        '/saldo': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as User;
          return SaldoScreen(user: user);
        },
        '/history': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as User;
          return HistoryScreen(user: user);
        },
      },
    );
  }
}

// La clase CatalogScreen real está en catalog_screen.dart