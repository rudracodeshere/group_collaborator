import 'package:flutter/material.dart';
import 'package:gca/screens/widget/add_task.dart';
import 'package:gca/screens/widget/task_tile.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.workspaceId});
  final workspaceId;
  @override
  State<TaskScreen> createState() {
    return _TaskScreenState();
  }
}

class _TaskScreenState extends State<TaskScreen> {
  List tasks = [1];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
     floatingActionButton: FloatingActionButton(
  onPressed: () {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: 20,bottom: MediaQuery.of(context).viewInsets.bottom+5),
        child: const AddTask(),
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
                  SizedBox(
                 
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      value: 4 / 5,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context)
                              .colorScheme
                              .primary),
                    ),
                  ),
                  SizedBox(width: 15),
                  Column(
                    children: [
                      Text(
                        'Team Tasks',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                      Text('4/5 Tasks Completed'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
              child: Divider(
                color: Colors.white,
              ),
            ),
            tasks.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return Dismissible(
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) {
                            setState(() {
                              tasks.removeAt(index);
                            });
                          },
                          background: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 5),
                              Text('Task Deleted'),
                            ],
                          ),
                          key: Key(index.toString()),
                          child: TaskTile(),
                        );
                      },
                    ))
                : Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task,
                            size: 40,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          SizedBox(height: 10),
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
                  ),
          ],
        ),
      ),
    );
  }
}
