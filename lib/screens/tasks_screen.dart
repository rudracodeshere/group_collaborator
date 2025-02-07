import 'package:flutter/material.dart';

class TasksScreen extends StatefulWidget {
  final String workspaceId;

  const TasksScreen({super.key, required this.workspaceId});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Tasks Screen (Workspace ID: ${widget.workspaceId})"),
            const SizedBox(height: 20),
            const Text("Dummy Task List will appear here..."),
          ],
        ),
      ),
    );
  }
}
