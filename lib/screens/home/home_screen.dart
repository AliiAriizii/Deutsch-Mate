import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeutschMate 🇩🇪', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guten Tag, علی 👋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Level 1 — A1 Explorer', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFCC00)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Color(0xFFFFCC00), size: 20),
                    SizedBox(width: 4),
                    Text('7 🔥', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF222222), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Menschen A1.1 Complete Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: 0.35,
                  backgroundColor: Colors.grey[800],
                  color: const Color(0xFFFFCC00),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('پوشش کامل ۱۲ درس + صوت، لایتنر و تمرین', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('ادامه مسیر →', style: TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}