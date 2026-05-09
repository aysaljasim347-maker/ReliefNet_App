const { Server } = require('socket.io');
let io;

function init(server) {
  io = new Server(server, {
    cors: { origin: '*', methods: ['GET', 'POST'] }
  });

  io.on('connection', (socket) => {
    console.log('Socket connected:', socket.id);

    socket.on('join', (userId) => {
      socket.join(`user_${userId}`);
      console.log(`User ${userId} joined room`);
    });

    socket.on('disconnect', () => {
      console.log('Socket disconnected:', socket.id);
    });
  });
}

function sendToUser(userId, event, data) {
  if (io) {
    io.to(`user_${userId}`).emit(event, data);
    console.log(`Sent to user_${userId}:`, event);
  }
}

module.exports = { init, sendToUser };