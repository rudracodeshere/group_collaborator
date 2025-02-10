// task_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gca/screens/widget/add_task.dart';
import 'package:gca/screens/widget/task_tile.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.workspaceId});
  final String workspaceId;
  @override
  State<TaskScreen> createState() {
    return _TaskScreenState();
  }
}

class _TaskScreenState extends State<TaskScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 5),
              child: AddTask(workspaceId: widget.workspaceId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('workspaces')
                          .doc(widget.workspaceId)
                          .collection('tasks')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final tasks = snapshot.data!.docs;
                          int completedTasks = 0;
                          if (tasks.isNotEmpty) {
                            completedTasks = tasks
                                .where((task) => task['completed'] == true)
                                .length;
                          }
                          double progress = tasks.isEmpty
                              ? 0
                              : completedTasks / tasks.length;

                          return SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          );
                        } else {
                          return SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          );
                        }
                      }),
                  const SizedBox(width: 15),
                  Column(
                    children: [
                      Text(
                        'Team Tasks',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                      StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('workspaces')
                              .doc(widget.workspaceId)
                              .collection('tasks')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final tasks = snapshot.data!.docs;
                              int completedTasks = 0;
                              if (tasks.isNotEmpty) {
                                completedTasks = tasks
                                    .where((task) => task['completed'] == true)
                                    .length;
                              }
                              return Text('${completedTasks}/${tasks.length} Tasks Completed');
                            } else {
                              return const Text('0/0 Tasks Completed');
                            }
                          }),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
              child: Divider(
                color: Colors.grey,
              ),
            ),
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('workspaces')
                    .doc(widget.workspaceId)
                    .collection('tasks')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final tasks = snapshot.data!.docs;
                    if (tasks.isNotEmpty) {
                      return Expanded(
                          child: ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final taskData =
                              tasks[index].data() as Map<String, dynamic>;
                          final taskId = tasks[index].id;
                          return Dismissible(
                            direction: DismissDirection.horizontal,
                            onDismissed: (direction) async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('workspaces')
                                    .doc(widget.workspaceId)
                                    .collection('tasks')
                                    .doc(taskId)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Task deleted!')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to delete task: $e')),
                                );
                              }
                            },
                            background: Container(
                              color: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.onError,
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Delete',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onError)),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              color: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('Delete',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onError)),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.delete,
                                    color: Theme.of(context).colorScheme.onError,
                                  ),
                                ],
                              ),
                            ),
                            key: Key(taskId),
                            child: TaskTile(
                              taskId: taskId,
                              taskTitle: taskData['title'] ?? 'No Title',
                              taskDescription:
                                  taskData['description'] ?? 'No Description',
                              taskDueDate: taskData['dueDate'] ?? 'No Due Date',
                              taskCompleted: taskData['completed'] ?? false,
                              workspaceId: widget.workspaceId,
                            ),
                          );
                        },
                      ));
                    } else {
                      return Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task,
                                size: 40,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No Tasks',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.8),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  } else if (snapshot.hasError) {
                    return Expanded(
                      child: Center(
                        child: Text('Error loading tasks: ${snapshot.error}'),
                      ),
                    );
                  } else {
                    return const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                }),
          ],
        ),
      ),
    );
  }
}