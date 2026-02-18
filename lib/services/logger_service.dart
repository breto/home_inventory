import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoggerService {
  // Singleton pattern
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void log(String message, {dynamic error, StackTrace? stack}) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    final logEntry = "[$timestamp] $message ${error ?? ''}";

    _logs.insert(0, logEntry); // Newest first
    debugPrint(logEntry); // Still print to console

    if (stack != null) {
      _logs.insert(0, "STACKTRACE: ${stack.toString().split('\n').take(3).join('\n')}");
    }

    // Keep only the last 100 logs to save memory
    if (_logs.length > 100) _logs.removeRange(100, _logs.length);
  }

  void clear() => _logs.clear();
}

final logger = LoggerService();