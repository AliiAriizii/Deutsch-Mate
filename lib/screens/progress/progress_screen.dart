import 'package:flutter/material.dart';
import '../../core/utils/format_spacing.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics & Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Overall Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menschen A1.1 Course', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                LinearProgressIndicator(value: 0.35, color: Color(0xFFFFCC00), backgroundColor: Colors.black),
                SizedBox(height: 8),
                Text('35% Completed (XP: 1,200)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Skills Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSkillRow('Vocabulary', 0.85),
          _buildSkillRow('Grammar & Quiz', 0.74),
          _buildSkillRow('Dialogues & Audio', 0.80),
        ],
      ),
    );
  }

  Widget _buildSkillRow(String skill, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: FormatSpacing().boxPadding(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(skill, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}