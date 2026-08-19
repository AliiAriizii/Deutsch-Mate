import 'package:flutter/material.dart';
import 'artikel_trainer_screen.dart';
import 'quiz_screen.dart';
import 'flashcard_screen.dart';
import 'writing_practice_screen.dart';
import 'final_exam_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Hub 🎮')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('انتخاب بخش تمرینی:', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          _buildHubCard(context, icon: Icons.category, title: 'Artikel Trainer (der/die/das)', subtitle: 'تخصص در تشخیص مقالات اسامی آلمانی', destination: const ArtikelTrainerScreen()),
          const SizedBox(height: 12),
          _buildHubCard(context, icon: Icons.quiz, title: 'Quiz & Grammar Test', subtitle: 'آزمون چهارگزینه‌ای همراه با دریافت XP', destination: const QuizScreen()),
          const SizedBox(height: 12),
          _buildHubCard(context, icon: Icons.style, title: 'Flashcards (Leitner Box)', subtitle: 'جعبه لایتنر هوشمند مرور لغات', destination: const FlashcardScreen()),
          const SizedBox(height: 12),
          _buildHubCard(context, icon: Icons.edit_note, title: 'Writing Practice', subtitle: 'تمرین املای کلمات و جمله‌سازی', destination: const WritingPracticeScreen()),
          const SizedBox(height: 12),
          _buildHubCard(context, icon: Icons.workspace_premium, title: 'A1.1 Final Exam', subtitle: 'آزمون جامع پایان ترم سطح A1.1', destination: const FinalExamScreen()),
        ],
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Widget destination}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFCC00), size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}