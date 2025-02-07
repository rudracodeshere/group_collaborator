import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String workspaceId;
  const ChatScreen({super.key, required this.workspaceId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final senderNameSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.phoneNumber)
          .get();
      final senderName = senderNameSnapshot.data()?['username'] as String? ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('messages').add({
        'workspaceId': widget.workspaceId,
        'senderId': user.uid,
        'senderName': senderName,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .where('workspaceId', isEqualTo: widget.workspaceId)
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No messages yet.'));

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final message = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final isMe = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                      return Align(
                        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.6) : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(message['senderName'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)), // Always show name
                              Text(message['text'] ?? '', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}