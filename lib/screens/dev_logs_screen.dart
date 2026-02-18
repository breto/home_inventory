import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';

class DevLogsScreen extends StatefulWidget {
  const DevLogsScreen({super.key});

  @override
  State<DevLogsScreen> createState() => _DevLogsScreenState();
}

class _DevLogsScreenState extends State<DevLogsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logger.logs.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logs copied")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(() => logger.clear()),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: logger.logs.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final log = logger.logs[index];
          final isError = log.toLowerCase().contains('error') || log.toLowerCase().contains('exception');
          return Text(
            log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isError ? Colors.red : Colors.grey[800],
            ),
          );
        },
      ),
    );
  }
}