// add_task.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddTask extends StatefulWidget {
  const AddTask({super.key, required this.workspaceId});
  final String workspaceId;
  @override
  State<AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> {
  DateTime tempToday = DateTime.now();
  String? selectedDate;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _taskTitle;
  String? _taskDes;
  @override
  void initState() {
    super.initState();
    selectedDate = '${tempToday.day}/${tempToday.month}/${tempToday.year}';
  }

  void _submitTask() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Map<String, dynamic> taskData = {
        'title': _taskTitle!,
        'description': _taskDes ?? '', // Use empty string if description is null
        'dueDate': selectedDate!,
        'createdAt': FieldValue.serverTimestamp(),
        'completed': false,
      };

      try {
        await FirebaseFirestore.instance
            .collection('workspaces')
            .doc(widget.workspaceId)
            .collection('tasks')
            .add(taskData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task: $e')),
        );
      }
    } else {
      print('Task not Submitted due to validation errors');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime today = DateTime.now();
    DateTime lastDate = DateTime(today.year + 100, today.month, today.day);

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: lastDate,
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate =
            '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Divider(
                    thickness: 1.5,
                    color: colorScheme.outline,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'New Task',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    thickness: 1.5,
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Title',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter task title';
                    }
                    return null;
                  },
                  onSaved: (value) => _taskTitle = value!.trim(),
                  autofocus: true,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    hintText: 'Enter task title',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  onSaved: (value) => _taskDes = value?.trim(), // Allow null description
                  maxLines: 4,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    hintText: 'Add task details (optional)',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Due Date',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.1),
                        width: 0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Icon(
                          Icons.calendar_month_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: Text(
                'Create Task',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}