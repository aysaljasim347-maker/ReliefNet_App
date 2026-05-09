import 'package:flutter/material.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';

class ChatBadgeProvider extends ChangeNotifier {
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  final _api = ApiClient();

  Future<void> refreshUnread() async {
    try {
      final res = await _api.dio.get('/chat');
      final chats = List<Map<String, dynamic>>.from(res.data['data']);
      _unreadCount = chats.fold(0, (sum, chat) => sum + (chat['unread_count']?? 0) as int);
      notifyListeners();
    } catch (e) {
      print('Badge refresh error: $e');
    }
  }

  void clear() {
    _unreadCount = 0;
    notifyListeners();
  }
}