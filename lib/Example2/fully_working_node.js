
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Store connected users and their media status
const users = {};

io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);

  socket.on('register', (userId) => {
    users[userId] = { socketId: socket.id, videoOn: true, audioOn: true };
    io.emit('userList', Object.keys(users));
  });

  socket.on('callUser', ({ from, to, offer }) => {
    const targetSocketId = users[to]?.socketId;
    if (targetSocketId) {
      io.to(targetSocketId).emit('incomingCall', { from, offer });
    }
  });

  socket.on('answerCall', ({ to, answer }) => {
    const targetSocketId = users[to]?.socketId;
    if (targetSocketId) {
      io.to(targetSocketId).emit('callAnswered', { answer });
    }
  });

  socket.on('iceCandidate', ({ to, candidate }) => {
    const targetSocketId = users[to]?.socketId;
    if (targetSocketId) {
      io.to(targetSocketId).emit('iceCandidate', { candidate });
    }
  });

  socket.on('callEnded', (data) => {
    const targetSocketId = users[data.to]?.socketId;
    if (targetSocketId) {
      io.to(targetSocketId).emit('callEnded');
    }
  });

  // Handle media status updates
  socket.on('mediaStatus', ({ to, videoOn, audioOn }) => {
    const targetSocketId = users[to]?.socketId;
    if (targetSocketId) {
      io.to(targetSocketId).emit('remoteMediaStatus', { videoOn, audioOn });
    }

    // Update sender's status
    const userId = Object.keys(users).find((key) => users[key].socketId === socket.id);
    if (userId) {
      users[userId].videoOn = videoOn;
      users[userId].audioOn = audioOn;
    }
  });

  socket.on('disconnect', () => {
    const userId = Object.keys(users).find((key) => users[key].socketId === socket.id);
    if (userId) {
      delete users[userId];
      io.emit('userList', Object.keys(users));
    }
    console.log('User disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});