import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

const String messagesCollection = 'messages';
const String usersCollection = 'users';
const String chatImagesFolder = 'chat_images';
const double imageMessageHeight = 200.0;
const int scrollAnimationDurationMs = 300;
const double messageBorderRadius = 12.0;
const double messagePadding = 8.0;
const double defaultPadding = 8.0;

enum ImageSourceType { camera, gallery }

class AuthService {
  FirebaseAuth get auth => FirebaseAuth.instance;
  User? get currentUser => auth.currentUser;
}

class UserService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<String> getUsername(String? phoneNumber) async {
    if (phoneNumber == null) return 'Anonymous';
    try {
      final userDoc =
          await firestore.collection(usersCollection).doc(phoneNumber).get();
      return (userDoc.data()?['username'] as String?) ?? 'Anonymous';
    } catch (e) {
      debugPrint(
          'Error fetching username: $e');
      return 'Anonymous';
    }
  }
}

class ChatService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final AuthService authService = AuthService();
  final UserService userService = UserService();

  Stream<QuerySnapshot> getMessagesStream(String workspaceId) {
    return firestore
        .collection(messagesCollection)
        .where('workspaceId', isEqualTo: workspaceId)
        .orderBy('timestamp',
            descending: false)
        .snapshots();
  }

  Future<String> uploadImage(File imageFile, String workspaceId) async {
    final imageName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageReference = storage
        .ref()
        .child(chatImagesFolder)
        .child(workspaceId)
        .child(imageName);
    await storageReference.putFile(imageFile);
    return storageReference.getDownloadURL();
  }

  Future<void> sendMessage({
    required String workspaceId,
    required String text,
    String? imageUrl,
    bool isImage = false,
  }) async {
    final user = authService.currentUser;
    if (user == null) {
      debugPrint(
          'User not logged in, cannot send message.');
      return;
    }

    final senderName = await userService.getUsername(user.phoneNumber);

    try {
      await firestore.collection(messagesCollection).add({
        'workspaceId': workspaceId,
        'senderId': user.uid,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isImage': isImage,
        'imageUrl':
            imageUrl ?? '',
      });
    } catch (error) {
      debugPrint(
          'Error sending message: $error');
    }
  }
}

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSourceType sourceType) async {
    try {
      final ImageSource source = sourceType == ImageSourceType.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      return await _picker.pickImage(source: source);
    } catch (e) {
      debugPrint(
          'Error picking image: $e');
      return null;
    }
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMyMessage;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isMyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isMyMessage
        ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
        : Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final alignment = isMyMessage ? Alignment.topRight : Alignment.topLeft;
    final crossAxisAlignment =
        isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Align(
      alignment: alignment,
      child: Container(

        margin: const EdgeInsets.symmetric(
        vertical: 4.0, horizontal: defaultPadding),
        padding: const EdgeInsets.all(messagePadding),
        decoration: BoxDecoration(

          color: backgroundColor,
          borderRadius: BorderRadius.circular(messageBorderRadius),
        ),
        child: Column(

          crossAxisAlignment: crossAxisAlignment,
          children: [
            Text(
              message['senderName'] ?? 'No Name',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message['isImage'] == true && message['imageUrl'] != null)
              CachedNetworkImage(
                imageUrl: message['imageUrl'] as String,
                height: imageMessageHeight,
                placeholder: (context, url) => AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(
                        10.0),
                    child: const CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Text('Failed to load image'),
              ),
            if (message['isImage'] != true)
              Text(
                message['text'] as String? ?? '',
                style: const TextStyle(fontSize: 16),
                softWrap: true,
                overflow: TextOverflow.clip,
              ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String workspaceId;

  const ChatScreen({super.key, required this.workspaceId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePickerService _imagePickerService = ImagePickerService();
  bool _isSendingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: scrollAnimationDurationMs),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleImageSelection(ImageSourceType sourceType) async {
    final pickedImageFile = await _imagePickerService.pickImage(sourceType);
    if (pickedImageFile != null) {
      await _uploadImageAndSend(pickedImageFile);
    }
  }

  Future<void> _uploadImageAndSend(XFile pickedImageFile) async {
    setState(() {
      _isSendingImage = true;
    });
    try {
      File imageFile = File(pickedImageFile.path);
      final imageUrl = await _chatService.uploadImage(
          imageFile, widget.workspaceId);
      await _chatService.sendMessage(
        workspaceId: widget.workspaceId,
        isImage: true,
        imageUrl: imageUrl,
        text: '',
      );
      _scrollToBottom();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to send image. Please try again. Error: $error')),
      );
      debugPrint('Error uploading and sending image: $error');
    } finally {
      setState(() {
        _isSendingImage = false;
      });
    }
  }

  void _pickAndSendImage() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSourceType.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _handleImageSelection(ImageSourceType.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendTextMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      await _chatService.sendMessage(
        workspaceId: widget.workspaceId,
        text: messageText,
      );
      _messageController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessagesStream(widget.workspaceId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error loading messages: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text(
                                'No messages yet. Send one to start the conversation!'));
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) =>
                          _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final message = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          final userId = AuthService()
                              .currentUser
                              ?.uid;
                          final isMyMessage = message['senderId'] == userId;

                          return ChatMessage(
                              message: message, isMyMessage: isMyMessage);
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration:
                              const InputDecoration(hintText: 'Type a message'),
                          onSubmitted: (_) =>
                              _sendTextMessage(),
                          enabled:
                              !_isSendingImage,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: _isSendingImage
                            ? null
                            : _pickAndSendImage,
                        tooltip: 'Send Image',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isSendingImage
                            ? null
                            : _sendTextMessage,
                        tooltip: 'Send Message',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSendingImage)
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}