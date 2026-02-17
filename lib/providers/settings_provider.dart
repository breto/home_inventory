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
  String _insuranceCompany = "";
  String get insuranceCompany => _insuranceCompany;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? "";
    _address = prefs.getString('address') ?? "";
    _policyNumber = prefs.getString('policyNumber') ?? "";
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    _insuranceCompany = prefs.getString('insuranceCompany') ?? "";
    notifyListeners();
  }

  Future<void> updateProfile(String name, String addr, String policy, String company) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    _address = addr;
    _policyNumber = policy;
    _insuranceCompany = company;
    await prefs.setString('userName', name);
    await prefs.setString('address', addr);
    await prefs.setString('policyNumber', policy);
    await prefs.setString('insuranceCompany', company);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = mode;
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }
}