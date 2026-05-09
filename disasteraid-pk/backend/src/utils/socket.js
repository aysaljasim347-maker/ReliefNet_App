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

    // ADD THESE 2 FOR CHAT
    socket.on('join_request', (requestId) => {
      socket.join(`request_${requestId}`);
      console.log(`Socket ${socket.id} joined request_${requestId}`);
    });

    socket.on('leave_request', (requestId) => {
      socket.leave(`request_${requestId}`);
      console.log(`Socket ${socket.id} left request_${requestId}`);
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

function getIO() {
  return io;
}

module.exports = { init, sendToUser, getIO };