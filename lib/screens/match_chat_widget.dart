// lib/screens/match_chat_widget.dart
// 対局中チャット UI（MatchScreen に埋め込み）

import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/network_service.dart';

class MatchChatWidget extends StatefulWidget {
  final String matchId;
  final bool expanded; // true=フルスクリーン風, false=下部パネル

  const MatchChatWidget({
    super.key,
    required this.matchId,
    this.expanded = false,
  });

  @override
  State<MatchChatWidget> createState() => _MatchChatWidgetState();
}

class _MatchChatWidgetState extends State<MatchChatWidget> {
  final ChatService _chatService = ChatService();
  final NetworkService _networkService = NetworkService();
  final ScrollController _scrollController = ScrollController();
  bool _showPresets = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPreset(String text) async {
    final user = _networkService.currentUser;
    if (user == null) return;

    final profile =
        await _networkService.getUserProfile(user.uid);
    await _chatService.sendPresetMessage(
      matchId: widget.matchId,
      senderId: user.uid,
      senderName: profile?.username ?? user.uid,
      presetText: text,
    );
    if (mounted) setState(() => _showPresets = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── メッセージ一覧 ──
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chatService.watchMessages(widget.matchId),
            builder: (context, snap) {
              final messages = snap.data ?? [];
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    '定型文でコミュニケーションしましょう',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                itemCount: messages.length,
                itemBuilder: (_, i) => _MessageBubble(
                  message: messages[i],
                  isMe: messages[i].senderId ==
                      _networkService.currentUser?.uid,
                ),
              );
            },
          ),
        ),

        // ── 定型文パネル ──
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _showPresets
              ? Container(
                  height: 120,
                  color: const Color(0xFF0F0F2E),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.35,
                    ),
                    itemCount: ChatService.presetMessages.length,
                    itemBuilder: (_, i) {
                      final text = ChatService.presetMessages[i];
                      return GestureDetector(
                        onTap: () => _sendPreset(text),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.brown.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── 送信ボタン行 ──
        Container(
          color: const Color(0xFF16213E),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // 定型文ボタン
              IconButton(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: _showPresets ? Colors.amber : Colors.white70,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _showPresets = !_showPresets),
                tooltip: '定型文',
              ),
              const Expanded(
                child: Text(
                  '定型文を使ってください',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.brown.shade700
              : Colors.grey.shade800,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style:
                    const TextStyle(color: Colors.amber, fontSize: 10),
              ),
            Text(
              message.text,
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 対局後チャット（感想戦） ──────────────────────────────────────

class PostMatchChatWidget extends StatefulWidget {
  final String matchId;

  const PostMatchChatWidget({super.key, required this.matchId});

  @override
  State<PostMatchChatWidget> createState() => _PostMatchChatWidgetState();
}

class _PostMatchChatWidgetState extends State<PostMatchChatWidget> {
  final ChatService _chatService = ChatService();
  final NetworkService _networkService = NetworkService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = _networkService.currentUser;
    if (user == null) return;

    final profile = await _networkService.getUserProfile(user.uid);
    _controller.clear();

    await _chatService.sendPostMatchMessage(
      matchId: widget.matchId,
      senderId: user.uid,
      senderName: profile?.username ?? user.uid,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('感想戦チャット',
              style: TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream:
                _chatService.watchPostMatchMessages(widget.matchId),
            builder: (context, snap) {
              final msgs = snap.data ?? [];
              return ListView.builder(
                controller: _scrollController,
                itemCount: msgs.length,
                itemBuilder: (_, i) => _MessageBubble(
                  message: msgs[i],
                  isMe: msgs[i].senderId ==
                      _networkService.currentUser?.uid,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 100,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '感想を送る...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send, color: Colors.amber),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
