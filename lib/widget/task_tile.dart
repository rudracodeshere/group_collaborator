// task_tile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TaskTile extends StatefulWidget {
  TaskTile({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskDueDate,
    required this.taskCompleted,
    required this.workspaceId,
  });
  final String taskId;
  final String taskTitle;
  final String taskDescription;
  final String taskDueDate;
  final bool taskCompleted;
  final String workspaceId;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  late bool _isChecked;
  @override
  void initState() {
    super.initState();
    _isChecked = widget.taskCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Checkbox(
          value: _isChecked,
          onChanged: (val) async {
            setState(() {
              _isChecked = val!;
            });
            try {
              await FirebaseFirestore.instance
                  .collection('workspaces')
                  .doc(widget.workspaceId)
                  .collection('tasks')
                  .doc(widget.taskId)
                  .update({'completed': val});
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update task status: $e')),
              );
              setState(() {
                _isChecked = !_isChecked; // Revert back on failure
              });
            }
          },
          shape: const CircleBorder(),
          visualDensity: VisualDensity.comfortable,
        ),
        title: Text(
          widget.taskTitle,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: _isChecked ? TextDecoration.lineThrough : null,
              color: _isChecked
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  : Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.taskDescription,
              style: TextStyle(
                  overflow: TextOverflow.ellipsis,
                  decoration: _isChecked ? TextDecoration.lineThrough : null,
                  color: _isChecked
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5)
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 2,
              softWrap: true,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Due: ${widget.taskDueDate}',
                    style: TextStyle(
                        decoration:
                            _isChecked ? TextDecoration.lineThrough : null,
                        color: _isChecked
                            ? Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.5)
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}