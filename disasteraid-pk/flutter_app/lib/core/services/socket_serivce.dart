import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  Function(Map<String, dynamic>)? onNotification;
  final Map<String, List<Function(dynamic)>> _listeners = {};

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
      if (onNotification!= null) {
        onNotification!(Map<String, dynamic>.from(data));
      }
    });

    socket!.onDisconnect((_) => print('Socket disconnected'));
  }

  // ADD: Generic emit
  void emit(String event, dynamic data) {
    if (socket?.connected == true) {
      socket!.emit(event, data);
    } else {
      print('Socket not connected, cannot emit: $event');
    }
  }

  // ADD: Generic listener
  void on(String event, Function(dynamic) callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
      socket?.on(event, (data) {
        for (var listener in _listeners[event]!) {
          listener(data);
        }
      });
    }
    _listeners[event]!.add(callback);
  }

  // ADD: Remove listener
  void off(String event, [Function(dynamic)? callback]) {
    if (callback == null) {
      _listeners.remove(event);
      socket?.off(event);
    } else {
      _listeners[event]?.remove(callback);
    }
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
    _listeners.clear();
  }
}