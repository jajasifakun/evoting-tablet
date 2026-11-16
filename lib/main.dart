import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/database_helper.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci ke mode Layar Penuh dan orientasi yang optimal untuk tablet Android
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Inisialisasi Database SQLite Lokal
  await DatabaseHelper.instance.database;

  runApp(const EvotingApp());
}

class EvotingApp extends StatelessWidget {
  const EvotingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Voting Pilkades Karang Mukti 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo.shade600,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
