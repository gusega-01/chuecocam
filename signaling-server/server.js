const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' }
});

const PORT = process.env.PORT || 3000;

// rooms: { sessionId: { host: socketId, viewer: socketId|null } }
const rooms = {};

app.get('/', (req, res) => {
  res.send('Servidor de señalización chuecoCAM activo');
});

io.on('connection', (socket) => {
  console.log('Cliente conectado:', socket.id);

  // El Host crea la sala al arrancar la transmisión
  socket.on('create-room', (sessionId) => {
    rooms[sessionId] = { host: socket.id, viewer: null };
    socket.join(sessionId);
    socket.data.sessionId = sessionId;
    socket.data.role = 'host';
    console.log(`Sala creada: ${sessionId} por host ${socket.id}`);
  });

  // El Viewer se une tras escanear el QR
  socket.on('join-room', (sessionId) => {
    const room = rooms[sessionId];
    if (!room) {
      socket.emit('room-error', 'La sesión no existe o expiró.');
      return;
    }
    if (room.viewer) {
      socket.emit('room-error', 'Ya hay un monitor conectado a esta sesión.');
      return;
    }
    room.viewer = socket.id;
    socket.join(sessionId);
    socket.data.sessionId = sessionId;
    socket.data.role = 'viewer';
    io.to(room.host).emit('viewer-joined', socket.id);
    console.log(`Viewer ${socket.id} se unió a la sala ${sessionId}`);
  });

  // Reenvío de señalización WebRTC (SDP offer/answer + ICE candidates)
  socket.on('offer', ({ sessionId, offer }) => {
    const room = rooms[sessionId];
    if (room && room.viewer) io.to(room.viewer).emit('offer', { offer, from: socket.id });
  });

  socket.on('answer', ({ sessionId, answer }) => {
    const room = rooms[sessionId];
    if (room && room.host) io.to(room.host).emit('answer', { answer, from: socket.id });
  });

  socket.on('ice-candidate', ({ sessionId, candidate }) => {
    const room = rooms[sessionId];
    if (!room) return;
    const target = socket.data.role === 'host' ? room.viewer : room.host;
    if (target) io.to(target).emit('ice-candidate', { candidate });
  });

  socket.on('disconnect', () => {
    const sessionId = socket.data.sessionId;
    if (sessionId && rooms[sessionId]) {
      const room = rooms[sessionId];
      if (room.host === socket.id) {
        if (room.viewer) io.to(room.viewer).emit('host-disconnected');
        delete rooms[sessionId];
      } else if (room.viewer === socket.id) {
        if (room.host) io.to(room.host).emit('viewer-disconnected');
        room.viewer = null;
      }
    }
    console.log('Cliente desconectado:', socket.id);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor de señalización chuecoCAM escuchando en puerto ${PORT}`);
});
