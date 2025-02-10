import 'package:flutter/material.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Checkbox(
            value: true,
            onChanged: (val) {},
            shape: CircleBorder(),
            visualDensity: VisualDensity.comfortable,
          ),
          title: Text(
            'Task',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task Description',
                style: TextStyle(overflow: TextOverflow.ellipsis),
                maxLines: 2,
                softWrap: true,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Due: 12/12/2021')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
