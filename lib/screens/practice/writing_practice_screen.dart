import 'package:flutter/material.dart';
import '../../core/utils/audio_helper.dart';
import 'package:deutsch_mate/core/constants/app_data.dart';

class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({super.key});

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  final TextEditingController _controller = TextEditingController();
  int _currentIndex = 0;
  String _message = '';
  Color _messageColor = Colors.white;
  bool _isAnswered = false;

  String _selectedLesson = 'Alle';
  List<Map<String, String>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadQuestions() {
    List<Map<String, String>> extracted = [];

    for (var lesson in AppData.lessons) {
      final title = lesson['title'] as String? ?? '';

      if (_selectedLesson != 'Alle' && title != _selectedLesson) {
        continue;
      }

      final sentences = lesson['sentences'] as List<dynamic>? ?? [];
      for (var item in sentences) {
        final de = item['de'] as String? ?? '';
        final fa = item['fa'] as String? ?? '';

        if (de.isNotEmpty && fa.isNotEmpty) {
          extracted.add({
            'prompt': 'ترجمه کنید: "$fa"',
            'answer': de,
            'lesson': title,
          });
        }
      }
    }

    extracted.shuffle();

    setState(() {
      _questions = extracted;
      _currentIndex = 0;
      _controller.clear();
      _message = '';
      _isAnswered = false;
    });
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // الگوریتم محاسبه میزان اختلاف دو رشته (Levenshtein Distance)
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[s2.length];
  }

  void _checkAnswer() {
    if (_controller.text.trim().isEmpty || _questions.isEmpty) return;

    final userAnswer = _normalize(_controller.text);
    final correctAnswer = _normalize(_questions[_currentIndex]['answer']!);

    final distance = _levenshteinDistance(userAnswer, correctAnswer);

    // حد مجاز خطا: برای جملات کوتاه ۱ کاراکتر و برای جملات بلندتر حداکثر ۲ کاراکتر
    final maxAllowedDistance = correctAnswer.length > 15 ? 2 : 1;

    setState(() {
      _isAnswered = true;
      if (distance == 0) {
        _message = 'Richtig! عالی بود ✅';
        _messageColor = Colors.greenAccent;
      } else if (distance <= maxAllowedDistance) {
        _message = 'قبوله! (با کمی اشتباه تایپی) ⚠️\nشکل کامل: "${_questions[_currentIndex]['answer']}"';
        _messageColor = Colors.orangeAccent;
      } else {
        _message = 'اشتباه! پاسخ درست:\n"${_questions[_currentIndex]['answer']}"';
        _messageColor = Colors.redAccent;
      }
    });

    AudioHelper.speakDe(_questions[_currentIndex]['answer']!);
  }

  void _nextQuestion() {
    if (_questions.isEmpty) return;

    setState(() {
      _controller.clear();
      _message = '';
      _isAnswered = false;
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
        _questions.shuffle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> lessonOptions = [
      'Alle',
      ...AppData.lessons.map((e) => e['title'] as String),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          _questions.isNotEmpty
              ? 'Writing Practice (${_currentIndex + 1}/${_questions.length})'
              : 'Writing Practice',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // منوی انتخاب درس
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'انتخاب درس:',
                    style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedLesson,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: lessonOptions.map((String lesson) {
                      return DropdownMenuItem<String>(
                        value: lesson,
                        child: Text(lesson == 'Alle' ? 'همه درس‌ها (Alle)' : lesson),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _selectedLesson = newValue;
                        _loadQuestions();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_questions.isNotEmpty) ...[
              // صورت سوال
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _questions[_currentIndex]['lesson'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _questions[_currentIndex]['prompt']!,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // فیلد ورودی متن
              TextField(
                controller: _controller,
                enabled: !_isAnswered,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'پاسخ به آلمانی...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFCC00)),
                  ),
                ),
                onSubmitted: (_) {
                  if (!_isAnswered) _checkAnswer();
                },
              ),
              const SizedBox(height: 20),

              // دکمه ثبت پاسخ / سوال بعدی
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isAnswered ? _nextQuestion : _checkAnswer,
                  child: Text(
                    _isAnswered ? 'سوال بعدی →' : 'بررسی پاسخ',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // پیام راهنما و فیدبک
              if (_message.isNotEmpty) ...[
                Text(
                  _message,
                  style: TextStyle(fontSize: 16, color: _messageColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFCC00), size: 32),
                  onPressed: () => AudioHelper.speakDe(_questions[_currentIndex]['answer']!),
                ),
              ],
            ] else ...[
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'هیچ جمله‌ای برای این درس یافت نشد!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}