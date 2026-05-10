import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    // Read socket URL from .env, fallback to localhost
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';
    // Strip /api suffix to get the socket server URL
    final socketUrl = baseUrl.replaceAll(RegExp(r'/api/?$'), '');

    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();
    socket!.onConnect((_) {
      print('Socket connected to $socketUrl');
      socket!.emit('join', userId);
    });

    socket!.on('notification', (data) {
      if (onNotification != null && data != null) {
        onNotification!(Map<String, dynamic>.from(data));
      }
    });

    socket!.onDisconnect((_) => print('Socket disconnected'));
    socket!.onConnectError((err) => print('Socket connection error: $err'));
  }

  /// Emit an event to the server
  void emit(String event, dynamic data) {
    if (socket?.connected == true) {
      socket!.emit(event, data);
    }
  }

  /// Listen for an event from the server
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

  /// Remove a listener for an event
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