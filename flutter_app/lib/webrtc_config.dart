// Configuración de servidores STUN/TURN.
// STUN (Google, gratis) ayuda a descubrir la IP pública del dispositivo.
// TURN (Open Relay Project, gratis) retransmite el video cuando la conexión
// directa falla por el CGNAT que usan la mayoría de operadoras móviles 4G/5G.
// Para producción real, considera crear tus propias credenciales TURN en
// https://www.metered.ca/tools/openrelay/ (tienen plan gratuito con más ancho de banda).
final Map<String, dynamic> webrtcIceConfig = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ],
  'sdpSemantics': 'unified-plan',
};
