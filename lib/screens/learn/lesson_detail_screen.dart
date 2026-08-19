import 'package:flutter/material.dart';
import '../../core/utils/audio_helper.dart';

class LessonDetailScreen extends StatelessWidget {
  final Map<String, dynamic> lessonData;

  const LessonDetailScreen({super.key, required this.lessonData});

  @override
  Widget build(BuildContext context) {
    final List words = lessonData['words'];
    final List sentences = lessonData['sentences'];

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonData['title']),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up, color: Color(0xFFFFCC00)),
            onPressed: () => AudioHelper.speakDe(lessonData['name']),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lessonData['name'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFCC00)),
          ),
          const SizedBox(height: 4),
          Text('موضوع: ${lessonData['topic']}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📐 گرامر درس:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),
                const SizedBox(height: 4),
                Text(lessonData['grammar'], style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Text('🧠 لغات کلیدی کتاب (Wortschatz)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          ...words.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(w['word']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    Row(
                      children: [
                        Text(w['translation']!, style: const TextStyle(fontSize: 14, color: Color(0xFFFFCC00))),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFCC00), size: 20),
                          onPressed: () => AudioHelper.speakDe(w['word']!),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          
          const SizedBox(height: 24),
          const Text('💬 جملات و مکالمات کاربردی (Sätze)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.3)),
            ),
            child: Column(
              children: sentences.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(left: BorderSide(color: Color(0xFFFFCC00), width: 4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['de']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(s['fa']!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFCC00)),
                        onPressed: () => AudioHelper.speakDe(s['de']!),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}