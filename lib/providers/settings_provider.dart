import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _userName = "";
  String _address = "";
  String _policyNumber = "";
  ThemeMode _themeMode = ThemeMode.system;

  String get userName => _userName;
  String get address => _address;
  String get policyNumber => _policyNumber;
  ThemeMode get themeMode => _themeMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? "";
    _address = prefs.getString('address') ?? "";
    _policyNumber = prefs.getString('policyNumber') ?? "";
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    notifyListeners();
  }

  Future<void> updateProfile(String name, String addr, String policy) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    _address = addr;
    _policyNumber = policy;
    await prefs.setString('userName', name);
    await prefs.setString('address', addr);
    await prefs.setString('policyNumber', policy);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = mode;
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }
}