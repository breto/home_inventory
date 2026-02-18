import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/metadata_provider.dart'; // NEW IMPORT
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Inventory Data (Items)
        ChangeNotifierProvider(
          create: (context) => InventoryProvider()..initializeData(),
        ),
        // 2. Metadata (Rooms & Categories) - SEPARATED
        ChangeNotifierProvider(
          create: (context) => MetadataProvider(), // Auto-loads on init
        ),
        // 3. Settings (Theme, Profile)
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Home Inventory',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}