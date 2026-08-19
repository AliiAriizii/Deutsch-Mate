import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFFFCC00),
              child: Text('علی', style: TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 16),
          Center(child: Text('Ali Arizi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text('A1 Explorer', style: TextStyle(color: Colors.grey))),
          SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.local_fire_department, color: Color(0xFFFFCC00)),
            title: Text('Daily Streak'),
            trailing: Text('7 Days 🔥', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(Icons.star, color: Color(0xFFFFCC00)),
            title: Text('Total XP'),
            trailing: Text('1,200 XP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}