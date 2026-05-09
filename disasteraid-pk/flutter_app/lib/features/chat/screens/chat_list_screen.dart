import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> chats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final res = await _api.dio.get('/chat');
      if (mounted) {
        setState(() {
          chats = List<Map<String, dynamic>>.from(res.data['data']);
          loading = false;
        });
        // Update global badge count
        context.read<ChatBadgeProvider>().refreshUnread();
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: loading
       ? const Center(child: CircularProgressIndicator())
        : chats.isEmpty
         ? const Center(child: Text('No active chats'))
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView.builder(
                itemCount: chats.length,
                itemBuilder: (_, i) {
                  final chat = chats[i];
                  final unread = chat['unread_count']?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(chat['other_user_name'][0].toUpperCase()),
                    ),
                    title: Text(
                      chat['other_user_name'],
                      style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      chat['last_message']?? 'Start chatting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          requestId: chat['request_id'],
                          otherUserName: chat['other_user_name'],
                        ),
                      ));
                      _loadChats(); // Refresh list + badge on return
                    },
                  );
                },
              ),
            ),
    );
  }
}