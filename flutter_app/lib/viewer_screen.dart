import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'webrtc_config.dart';

class ViewerScreen extends StatefulWidget {
  final String serverUrl;
  final String sessionId;
  const ViewerScreen({super.key, required this.serverUrl, required this.sessionId});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late io.Socket socket;
  RTCPeerConnection? _pc;
  final _remoteRenderer = RTCVideoRenderer();
  String status = 'Conectando...';
  bool muted = false;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _remoteRenderer.initialize();
    _connect();
  }

  void _connect() {
    socket = io.io(
      widget.serverUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    socket.connect();

    socket.onConnect((_) {
      socket.emit('join-room', widget.sessionId);
      setState(() => status = 'Esperando video del host...');
    });

    socket.on('offer', (data) async {
      await _createPeerConnection();
      final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
      await _pc!.setRemoteDescription(offer);
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      socket.emit('answer', {
        'sessionId': widget.sessionId,
        'answer': {'sdp': answer.sdp, 'type': answer.type}
      });
    });

    socket.on('ice-candidate', (data) async {
      final c = data['candidate'];
      if (c != null) {
        await _pc?.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    });

    socket.on('host-disconnected', (_) {
      setState(() {
        status = 'La cámara se desconectó';
        connected = false;
      });
    });

    socket.on('room-error', (msg) {
      setState(() => status = 'Error: $msg');
    });
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(webrtcIceConfig);

    _pc!.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {
          connected = true;
          status = 'En vivo';
        });
      }
    };

    _pc!.onIceCandidate = (candidate) {
      socket.emit('ice-candidate', {
        'sessionId': widget.sessionId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };
  }

  void _reconnect() {
    setState(() {
      connected = false;
      status = 'Reconectando...';
    });
    _pc?.close();
    _pc = null;
    socket.dispose();
    _connect();
  }

  void _toggleMute() {
    muted = !muted;
    _remoteRenderer.srcObject?.getAudioTracks().forEach((t) => t.enabled = !muted);
    setState(() {});
  }

  @override
  void dispose() {
    _pc?.close();
    _remoteRenderer.dispose();
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
            Positioned.fill(
              child: connected
                  ? RTCVideoView(_remoteRenderer)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(status, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'chuecoCAM',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
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
                  _btn(muted ? Icons.mic_off : Icons.mic, _toggleMute),
                  const SizedBox(width: 20),
                  _btn(Icons.refresh, _reconnect),
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
