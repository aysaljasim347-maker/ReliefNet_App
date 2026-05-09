import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  Function(Map<String, dynamic>)? onNotification;

  void connect(int userId) {
    if (socket?.connected == true) return;
    
    socket = IO.io('http://YOUR_IP:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();
    socket!.onConnect((_) {
      print('Socket connected');
      socket!.emit('join', userId);
    });

    socket!.on('notification', (data) {
      print('Notification received: $data');
      if (onNotification != null) {
        onNotification!(Map<String, dynamic>.from(data));
      }
    });

    socket!.onDisconnect((_) => print('Socket disconnected'));
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }
}