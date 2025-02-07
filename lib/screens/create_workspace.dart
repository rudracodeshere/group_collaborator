import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _workspaceIdController = TextEditingController();
  bool _isLoading = false;
  int _selectedIndex = 0;

  Future<void> _createWorkspace() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final uuid = Uuid();
      String workspaceJoinId = uuid.v4();
      workspaceJoinId = workspaceJoinId.substring(0, 4);
      print('uuid $workspaceJoinId');
      await FirebaseFirestore.instance.collection('workspaces').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': user.uid,
        'workspaceJoinId': workspaceJoinId,
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinWorkspace() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final workspaceQuery = await FirebaseFirestore.instance.collection('workspaces').where('workspaceJoinId',isEqualTo: _workspaceIdController.text.trim()).get();
       if (workspaceQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workspace not found.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final workspaceDoc = workspaceQuery.docs.first;
    final workspaceId = workspaceDoc.id;

    List<dynamic> currentMembers = workspaceDoc.data()['members'] ?? [];
    if (currentMembers.contains(user.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already a member of this workspace.'),
          backgroundColor: Colors.yellow,
        ),
      );
      return;
    }

    currentMembers.add(user.uid);
    await FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .update({'members': currentMembers});



      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined workspace successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      if(!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _workspaceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appbarTitle = ['Create Workspace', 'Join Workspace'];

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add),
            label: 'Join',
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          appbarTitle[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.transparent,
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
              child: _selectedIndex == 0
              ? _buildCreateWorkspaceForm()
              : _buildJoinWorkspaceForm(),
        ),
      ),
    );
  }

  Widget _buildCreateWorkspaceForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Workspace',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a workspace for your team to collaborate',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'Enter workspace name',
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a workspace name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Enter workspace description',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createWorkspace,
                style: ElevatedButton.styleFrom(
                  elevation: 10,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text(
                            'Create Workspace',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinWorkspaceForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join Workspace',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join an existing workspace to collaborate with your team',
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _workspaceIdController,
            decoration: InputDecoration(
              labelText: 'Workspace ID',
              hintText: 'Enter workspace ID',
              prefixIcon: const Icon(Icons.work_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a workspace ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _joinWorkspace,
              style: ElevatedButton.styleFrom(
                elevation: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_add),
                        SizedBox(width: 8),
                        Text(
                          'Join Workspace',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
