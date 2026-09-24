import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'webrtc_config.dart';

class HostScreen extends StatefulWidget {
  final String serverUrl;
  const HostScreen({super.key, required this.serverUrl});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late io.Socket socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final String sessionId = const Uuid().v4().substring(0, 8);
  String status = 'Iniciando cámara...';
  bool viewerConnected = false;
  bool frontCamera = false;
  String quality = 'media'; // baja / media / alta

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _startLocalStream();
    _connectSignaling();
    WakelockPlus.enable(); // evita que la pantalla se bloquee y corte la cámara
  }

  Map<String, dynamic> _videoConstraints() {
    switch (quality) {
      case 'baja':
        return {'width': 320, 'height': 240, 'frameRate': 15};
      case 'alta':
        return {'width': 1280, 'height': 720, 'frameRate': 30};
      default:
        return {'width': 640, 'height': 480, 'frameRate': 24};
    }
  }

  Future<void> _startLocalStream() async {
    final constraints = {
      'audio': true,
      'video': {
        'facingMode': frontCamera ? 'user' : 'environment',
        ..._videoConstraints(),
      }
    };
    final stream = await navigator.mediaDevices.getUserMedia(constraints);
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = stream;
    _localRenderer.srcObject = _localStream;
    if (mounted) setState(() => status = 'Esperando conexión del monitor...');
  }

  void _connectSignaling() {
    socket = io.io(
      widget.serverUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    socket.connect();

    socket.onConnect((_) {
      socket.emit('create-room', sessionId);
    });

    socket.on('viewer-joined', (_) async {
      setState(() => viewerConnected = true);
      await _createPeerConnectionAndOffer();
    });

    socket.on('answer', (data) async {
      final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
      await _pc?.setRemoteDescription(answer);
    });

    socket.on('ice-candidate', (data) async {
      final c = data['candidate'];
      if (c != null) {
        await _pc?.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    });

    socket.on('viewer-disconnected', (_) {
      setState(() {
        viewerConnected = false;
        status = 'Monitor desconectado. Esperando reconexión...';
      });
      _pc?.close();
      _pc = null;
    });

    socket.on('room-error', (msg) {
      setState(() => status = 'Error: $msg');
    });
  }

  Future<void> _createPeerConnectionAndOffer() async {
    _pc = await createPeerConnection(webrtcIceConfig);
    _localStream?.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    _pc!.onIceCandidate = (candidate) {
      socket.emit('ice-candidate', {
        'sessionId': sessionId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    socket.emit('offer', {
      'sessionId': sessionId,
      'offer': {'sdp': offer.sdp, 'type': offer.type}
    });
    setState(() => status = 'Transmitiendo en vivo');
  }

  Future<void> _replaceVideoTrack() async {
    if (_pc != null && _localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      final senders = await _pc!.getSenders();
      final videoSender = senders.firstWhere(
        (s) => s.track?.kind == 'video',
        orElse: () => senders.first,
      );
      await videoSender.replaceTrack(videoTrack);
    }
  }

  Future<void> _switchCamera() async {
    frontCamera = !frontCamera;
    await _startLocalStream();
    await _replaceVideoTrack();
  }

  Future<void> _changeQuality(String q) async {
    quality = q;
    await _startLocalStream();
    await _replaceVideoTrack();
  }

  String get qrData => jsonEncode({'server': widget.serverUrl, 'sessionId': sessionId});

  @override
  void dispose() {
    WakelockPlus.disable();
    _pc?.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localRenderer.dispose();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: RTCVideoView(_localRenderer, mirror: frontCamera)),
            // Marca de agua "chuecoCAM" en la parte superior de la vista en vivo
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'chuecoCAM',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 50,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            if (!viewerConnected)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Escanea este código desde el\ncelular Monitor',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(data: qrData, size: 220),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _btn(Icons.cameraswitch, _switchCamera),
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.hd, color: Colors.white),
                    onSelected: _changeQuality,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'baja', child: Text('Baja (ahorra datos)')),
                      PopupMenuItem(value: 'media', child: Text('Media')),
                      PopupMenuItem(value: 'alta', child: Text('Alta')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return CircleAvatar(
      backgroundColor: Colors.black54,
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }
}
