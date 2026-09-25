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
      TextEditingController(text: 'https://TU-SERVIDOR.onrender.com');

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
    if (result == null) return; // el usuario volvió sin escanear nada
    try {
      final data = jsonDecode(result);
      final server = data['server'];
      final sessionId = data['sessionId'];
      if (server == null || sessionId == null) {
        throw const FormatException('Faltan los campos server/sessionId en el QR');
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(serverUrl: server, sessionId: sessionId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Código QR no reconocido'),
          content: Text('Contenido leído:\n"$result"\n\nError: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  PermissionStatus? _cameraStatus;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (mounted) setState(() => _cameraStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código QR')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cameraStatus == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_cameraStatus!.isGranted) {
      // Permiso denegado (o denegado permanentemente): mostramos el motivo
      // real en vez del icono genérico de mobile_scanner.
      final permanentemente = _cameraStatus!.isPermanentlyDenied;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                permanentemente
                    ? 'El permiso de cámara fue denegado permanentemente.\nTenés que habilitarlo manualmente desde Ajustes.'
                    : 'Se necesita permiso de cámara para escanear el código QR.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: permanentemente ? openAppSettings : _checkPermission,
                child: Text(permanentemente ? 'Abrir Ajustes' : 'Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Permiso concedido: mostramos el escáner, con errorBuilder para ver
    // el motivo real si la cámara falla al iniciar por otra causa.
    return MobileScanner(
      errorBuilder: (context, error, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Error al iniciar la cámara:\n${error.toString()}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      onDetect: (capture) {
        if (_handled) return; // evita popear más de una vez con el mismo QR en cámara
        final barcodes = capture.barcodes;
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
          _handled = true;
          Navigator.pop(context, barcodes.first.rawValue);
        }
      },
    );
  }
}
