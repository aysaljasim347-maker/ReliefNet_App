
import 'package:disasteraid_pk/core/services/socket_service.dart';
import 'package:disasteraid_pk/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:disasteraid_pk/core/api/api_client.dart';
import '../../../core/utils/safe_data_handler.dart';
import '../../../shared/widgets/error_state.dart';

class ChatScreen extends StatefulWidget {
  final int requestId;
  final String otherUserName;
  const ChatScreen({super.key, required this.requestId, required this.otherUserName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _socket = SocketService();
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  String? error;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = _api.currentUser?['id']; // Cache it
    _loadMessages();
    _socket.emit('join_request', widget.requestId);

    _socket.on('new_message', (data) {
      final map = SafeDataHandler.extractMap(data);
      if (map['request_id'] == widget.requestId && mounted) {
        setState(() => messages.add(map));
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final res = await _api.dio.get('/chat/${widget.requestId}');
      if (mounted) {
        setState(() {
          final data = SafeDataHandler.extractList(res.data);
          messages = data.map((e) => SafeDataHandler.extractMap(e)).toList();
          loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = ApiClient.messageFromError(e, 'Failed to load messages');
          loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    try {
      await _api.dio.post('/chat/${widget.requestId}', data: {'message': text});
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.messageFromError(e, 'Failed to send message'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _socket.emit('leave_request', widget.requestId);
    _socket.off('new_message'); // Clean up listener
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return ErrorState(message: error!, onRetry: _loadMessages);

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMe = m['sender_id'] == currentUserId; // Use cached ID
                    return Align(
                      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe? Theme.of(context).colorScheme.primary : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['message'],
                              style: TextStyle(color: isMe? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateTime.parse(m['created_at']).toLocal().toString().substring(11, 16),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle: 'Start the conversation!',
      compact: true,
    );
  }
}