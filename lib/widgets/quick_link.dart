import 'package:flutter/material.dart';

class QuickLink extends StatelessWidget {
  final String title;
  const QuickLink({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        // Implement your navigation or action here.
      },
      leading: Icon(Icons.link, color: Colors.blue[900]!),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.blue[900],
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.blue[900]!),
    );
  }
}
