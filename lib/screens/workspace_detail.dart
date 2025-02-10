import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gca/screens/chat_screen.dart';
import 'package:gca/screens/home.dart';
import 'package:gca/screens/tasks_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gca/screens/call_screen.dart'; // Import CallPage
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage

class WorkspaceDetailScreen extends StatefulWidget {
  final String workspaceId;
  final String workspaceName;
  final String workspaceJoinId;

  const WorkspaceDetailScreen({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceJoinId,
  });

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _selectedIndex == 2 // Conditionally render AppBar
          ? null
          : AppBar(
              title: Text(widget.workspaceName),
              centerTitle: true,
              elevation: 0,
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
              iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _navigateToSettings(context),
                ),
              ],
            ),
      body: _buildBody(), // Call a new method to build the body
      bottomNavigationBar: _selectedIndex == 2 // Conditionally render BottomNavigationBar
          ? null
          : _buildBottomNavBar(colorScheme),
    );
  }

  // New method to build the body based on _selectedIndex
  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return ChatScreen(workspaceId: widget.workspaceId);
    } else if (_selectedIndex == 1) {
      return TaskScreen(workspaceId: widget.workspaceId);
    } else if (_selectedIndex == 2) {
      return CallPage(callID: widget.workspaceId); // Add CallPage here
    } else {
      // Fallback or handle other cases if needed.
      return Container(); // Or any default widget
    }
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          workspaceId: widget.workspaceId,
          workspaceJoinId: widget.workspaceJoinId,
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar(ColorScheme colorScheme) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_box_outlined),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_call),
          label: 'Video Call',
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String workspaceId;
  final String workspaceJoinId;

  const SettingsScreen({
    super.key,
    required this.workspaceId,
    required this.workspaceJoinId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;
  bool _deleteConfirmationVisible = false;

  Future<void> _deleteWorkspace() async {
    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final workspaceRef = FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId);

      final workspaceDoc = await workspaceRef.get();
      if (!workspaceDoc.exists || workspaceDoc['creatorId'] != user.uid) {
        throw Exception(workspaceDoc.exists
            ? 'Only the owner can delete the workspace'
            : 'Workspace not found');
      }

      final batch = FirebaseFirestore.instance.batch();

      // Delete workspace
      batch.delete(workspaceRef);

      // Delete related messages
      final messages = await FirebaseFirestore.instance
          .collection('messages')
          .where('workspaceId', isEqualTo: widget.workspaceId)
          .get();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Delete related tasks
      final tasks = await FirebaseFirestore.instance
          .collection('tasks')
          .where('workspaceId', isEqualTo: widget.workspaceId)
          .get();
      for (final doc in tasks.docs) {
        batch.delete(doc.reference);
      }

      // --- START: Delete Images from Storage ---
      final storage = FirebaseStorage.instance;
      final workspaceImageFolderRef = storage.ref().child('chat_images').child(widget.workspaceId);

      try {
        // List all items (files) within the workspace image folder
        final ListResult listResult = await workspaceImageFolderRef.listAll();
        final List<Reference> items = listResult.items;

        // Delete each image file
        await Future.wait(items.map((item) => item.delete())); // Delete all images in parallel

        // Optionally, you can also try to delete the workspace folder itself (if it's empty after deleting files)
        // Note: Deleting a folder might not be directly supported in Firebase Storage,
        // and might become empty after deleting all files inside it.
        // If you need to explicitly delete empty folders, you might need to use Firebase Admin SDK (server-side).
        // For now, just deleting the files within the folder is sufficient.

      } catch (storageError) {
        debugPrint('Error deleting images from storage: $storageError');
        // It's important to handle errors here, but consider if you want to block workspace deletion
        // if image deletion fails. For now, we'll just print the error and continue deleting Firestore data.
      }
      // --- END: Delete Images from Storage ---


      await batch.commit();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deleteConfirmationVisible = false;
        });
      }
    }
  }

  void _handleDelete() {
    if (_deleteConfirmationVisible) {
      _deleteWorkspace();
    } else {
      setState(() => _deleteConfirmationVisible = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _deleteConfirmationVisible) {
          setState(() => _deleteConfirmationVisible = false);
        }
      });
    }
  }

  Future<void> _copyJoinCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.workspaceJoinId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join code copied!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to copy code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildJoinCodeCard(colorScheme),
            const SizedBox(height: 20),
            _buildDeleteCard(colorScheme),
          ],
        ),
      ),
    );
  }

  Card _buildJoinCodeCard(ColorScheme colorScheme) {
    return Card(
      child: ListTile(
        title: Text(widget.workspaceJoinId),
        subtitle: const Text('Workspace Join Code'),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copyJoinCode,
        ),
      ),
    );
  }

  Card _buildDeleteCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.errorContainer,
      child: ListTile(
        title: Center(
          child: _isDeleting
              ? const CircularProgressIndicator()
              : Text(
                  _deleteConfirmationVisible
                      ? 'Confirm Delete'
                      : 'Delete Workspace',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
        ),
        onTap: _isDeleting ? null : _handleDelete,
        trailing: _deleteConfirmationVisible
            ? Icon(Icons.warning, color: colorScheme.error)
            : null,
      ),
    );
  }
}