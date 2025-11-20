import 'package:cityweather/pages/accueil.dart';
import 'package:cityweather/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  // Configuration de la barre de statut
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityWeather',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AccueilPage(),
    );
  }
}

