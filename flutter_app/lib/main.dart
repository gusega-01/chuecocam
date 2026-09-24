import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'host_screen.dart';
import 'viewer_screen.dart';

void main() {
  runApp(const ChuecoCamApp());
}

class ChuecoCamApp extends StatelessWidget {
  const ChuecoCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chuecoCAM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cambia este valor por defecto por la URL de tu servidor ya desplegado.
  final _serverController =
    TextEditingController(text: 'https://chuecocam-1.onrender.com');

  Future<void> _goHost() async {
    await [Permission.camera, Permission.microphone].request();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostScreen(serverUrl: _serverController.text.trim()),
      ),
    );
  }

  Future<void> _goViewer() async {
    await Permission.camera.request();
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result != null) {
      try {
        final data = jsonDecode(result);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewerScreen(
              serverUrl: data['server'],
              sessionId: data['sessionId'],
            ),
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código QR no válido')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('chuecoCAM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 72, color: Colors.deepOrange),
            const SizedBox(height: 24),
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'URL del servidor de señalización',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _goHost,
              icon: const Icon(Icons.home),
              label: const Text('Usar como Cámara (Host)'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _goViewer,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Usar como Monitor (Escanear QR)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código QR')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            Navigator.pop(context, barcodes.first.rawValue);
          }
        },
      ),
    );
  }
}
