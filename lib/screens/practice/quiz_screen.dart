import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedChoice;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Ich ___ aus dem Iran.',
      'choices': ['bist', 'bin', 'sind', 'ist'],
      'answer': 1,
    },
    {
      'question': 'Wie ___ du?',
      'choices': ['heiße', 'heißt', 'sein', 'kommt'],
      'answer': 1,
    },
    {
      'question': 'Das ist ___ Buch.',
      'choices': ['der', 'die', 'das', 'den'],
      'answer': 2,
    },
  ];

  void _answerQuestion(int choiceIndex) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedChoice = choiceIndex;
      if (choiceIndex == _questions[_questionIndex]['answer']) {
        _score += 20;
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _answered = false;
        _selectedChoice = null;
        if (_questionIndex < _questions.length - 1) {
          _questionIndex++;
        } else {
          _questionIndex = 0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_questionIndex];
    return Scaffold(
      appBar: AppBar(title: Text('Quiz (${_questionIndex + 1}/${_questions.length})')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Score: $_score XP', style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(q['question'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            ...List.generate(q['choices'].length, (index) {
              Color btnColor = const Color(0xFF1A1A1A);
              if (_answered) {
                if (index == q['answer']) {
                  btnColor = Colors.green[800]!;
                } else if (index == _selectedChoice) {
                  btnColor = Colors.red[800]!;
                }
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _answerQuestion(index),
                  child: Text(q['choices'][index], style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}