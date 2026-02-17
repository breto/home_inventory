import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/settings_provider.dart'; // New Import
import 'screens/home_screen.dart';

void main() async {
  // Ensure Flutter is initialized before loading SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Load Inventory Data
        ChangeNotifierProvider(
          create: (context) => InventoryProvider()..initializeData(),
        ),
        // Load Insurance Profile & Theme Settings
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Home Inventory',
            debugShowCheckedModeBanner: false,
            // Standard Light Theme
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            // Dark Theme Configuration
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            // This line tells the app which mode to use based on your Settings Screen
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}