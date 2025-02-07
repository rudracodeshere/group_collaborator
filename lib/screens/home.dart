import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gca/screens/create_workspace.dart';
import 'package:gca/screens/workspace_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  String? username;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.phoneNumber)
        .get();

    if (userDoc.exists) {
      setState(() {
        username = userDoc.get('username') as String?;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _setUsername(BuildContext context) async {
    final newUsername = _usernameController.text.trim();

    if (newUsername.length < 5 || newUsername.contains(' ')) {
      _showErrorSnackBar(context,
          'Username must be at least 5 characters and cannot contain spaces.');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _showErrorSnackBar(
            context, 'Username already exists. Try another one.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.phoneNumber)
          .set({
        'phoneNumber': FirebaseAuth.instance.currentUser?.phoneNumber,
        'username': newUsername,
      });

      setState(() {
        username = newUsername;
      });
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to set username. Try again.');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLow,
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    if (username == null) {
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLow,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter Username', style: TextStyle(color: colorScheme.onSurface, fontSize: 20)),
                const SizedBox(height: 10),
                TextField(
                  controller: _usernameController,
                  autofocus: true,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  onSubmitted: (_) => _setUsername(context),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  ),
                  onPressed: () => _setUsername(context),
                  child: const Text('Verify Username'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
          title: const Text('Home'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout, color: colorScheme.onSurfaceVariant),
              onPressed: () {
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ));
              },
            ),
          ],
          elevation: 0,
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(child: _buildWorkspaceList(context, colorScheme)),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateWorkspaceScreen(),
                  ),
                ),
                child: Text('Create or Join Workspace', style: TextStyle(color: colorScheme.onPrimaryContainer)),
              ),
            ),
          ],
        ));
  }

  Widget _buildWorkspaceList(BuildContext context, ColorScheme colorScheme) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workspaces')
          .where('members', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Hi $username', style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('No workspaces yet. Create one!', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        final workspaces = snapshot.data!.docs;
        return ListView.builder(
          itemCount: workspaces.length,
          itemBuilder: (_, index) {
            final workspace = workspaces[index];
            return Card(
              color: colorScheme.surfaceContainer,
              elevation: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                title: Text(workspace['name'], style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                subtitle: Text(workspace['description'], style: TextStyle(color: colorScheme.onSurfaceVariant)),
                trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkspaceDetailScreen(
                      workspaceId: workspace.id,
                      workspaceName: workspace['name'],
                      workspaceJoinId: workspace['workspaceJoinId'],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}