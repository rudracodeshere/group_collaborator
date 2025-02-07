import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// --- Constants and Enums ---
const String messagesCollection = 'messages';
const String usersCollection = 'users';
const String chatImagesFolder = 'chat_images';
const double imageMessageHeight = 200.0;
const int scrollAnimationDurationMs = 300;
const double messageBorderRadius = 12.0;
const double messagePadding = 8.0;
const double defaultPadding = 8.0;

enum ImageSourceType { camera, gallery }

// --- Services ---
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
          'Error fetching username: $e'); // Use debugPrint for non-critical errors
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
            descending: false) // Ensure messages are in ascending order
        .snapshots();
  }

  Future<String> uploadImage(File imageFile, String workspaceId) async {
    // Modified to accept workspaceId
    final imageName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // Storage path now includes workspaceId
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
          'User not logged in, cannot send message.'); // Debug print for non-critical issues
      return; // Early return if user is not logged in
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
            imageUrl ?? '', // Ensure imageUrl is always provided, even if empty
      });
    } catch (error) {
      debugPrint(
          'Error sending message: $error'); // Debug print for non-critical issues
      // Consider more robust error handling for production (e.g., retry mechanism, error reporting)
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
          'Error picking image: $e'); // Debug print for non-critical issues
      return null; // Handle error gracefully by returning null
    }
  }
}

// --- Chat Message Widget ---
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
            ), //message['imageUrl']
            if (message['isImage'] == true && message['imageUrl'] != null)
              CachedNetworkImage(
                imageUrl: message['imageUrl'] as String,
                height: imageMessageHeight,
                placeholder: (context, url) => AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    // Optional: Container for background color if needed
                    padding: const EdgeInsets.all(
                        10.0), // Optional padding for indicator
                    child: const CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Text('Failed to load image'),
              ),
            if (message['isImage'] != true)
              Text(message['text'] as String? ?? '',
                  style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// --- Chat Screen ---
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
  bool _isSendingImage = false; // State to track if image is sending

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
      _isSendingImage = true; // Start loading
    });
    try {
      File imageFile = File(pickedImageFile.path);
      final imageUrl = await _chatService.uploadImage(
          imageFile, widget.workspaceId); // Pass workspaceId here
      await _chatService.sendMessage(
        workspaceId: widget.workspaceId,
        isImage: true,
        imageUrl: imageUrl,
        text: '', // Text is empty for image messages
      );
      _scrollToBottom(); // Scroll to bottom after sending message
    } catch (error) {
      // Consider showing a snackbar or alert dialog to inform the user about the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to send image. Please try again. Error: $error')),
      );
      debugPrint('Error uploading and sending image: $error');
    } finally {
      setState(() {
        _isSendingImage = false; // End loading regardless of success or failure
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
      _scrollToBottom(); // Scroll to bottom after sending message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // Use Stack to overlay loader
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
                          _scrollToBottom()); // Scroll to bottom on message load

                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final message = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          final userId = AuthService()
                              .currentUser
                              ?.uid; // Get current user ID directly here for simplicity
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
                              _sendTextMessage(), // Send message on Enter key
                          enabled:
                              !_isSendingImage, // Disable input when sending image
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: _isSendingImage
                            ? null
                            : _pickAndSendImage, // Disable button when sending image
                        tooltip: 'Send Image',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _isSendingImage
                            ? null
                            : _sendTextMessage, // Disable button when sending image
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
              // Overlay loader on top of everything
              child: Container(
                color: Colors.black
                    .withOpacity(0.5), // Semi-transparent background
                child: const Center(
                  child: CircularProgressIndicator(), // Centered loader
                ),
              ),
            ),
        ],
      ),
    );
  }
}
