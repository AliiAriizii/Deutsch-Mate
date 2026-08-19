import 'package:flutter/material.dart';
import 'package:deutsch_mate/core/constants/app_data.dart'; // حتماً مطمئن شو که فایل AppData در کنار این فایل باشه یا ایمپورت شده باشه

class ArtikelTrainerScreen extends StatefulWidget {
  const ArtikelTrainerScreen({super.key});

  @override
  State<ArtikelTrainerScreen> createState() => _ArtikelTrainerScreenState();
}

class _ArtikelTrainerScreenState extends State<ArtikelTrainerScreen> {
  int _currentIndex = 0;
  int _score = 0;
  String? _feedbackMessage;
  Color? _feedbackColor;

  String _selectedLesson = 'Alle'; // گزینه پیش‌فرض: همه درس‌ها
  List<Map<String, String>> _activeItems = [];

  @override
  void initState() {
    super.initState();
    _loadItemsForSelectedLesson();
  }

  // استخراج و فیلتر کردن کلمات دارای ارتیکل از AppData
  void _loadItemsForSelectedLesson() {
    List<Map<String, String>> extractedItems = [];

    for (var lesson in AppData.lessons) {
      final title = lesson['title'] as String? ?? '';
      
      // اگر درسی خاص انتخاب شده و با این درس یکی نیست، نادیده‌اش بگیر
      if (_selectedLesson != 'Alle' && title != _selectedLesson) {
        continue;
      }

      final words = lesson['words'] as List<dynamic>? ?? [];
      for (var item in words) {
        final String wordText = item['word'] ?? '';
        final String translation = item['translation'] ?? '';
        final lower = wordText.trim().toLowerCase();

        // چک کردن اینکه آیا کلمه با ارتیکل‌های اصلی شروع میشه یا نه
        if (lower.startsWith('der ') || lower.startsWith('die ') || lower.startsWith('das ')) {
          final parts = wordText.trim().split(' ');
          final article = parts[0].toLowerCase();
          final noun = parts.sublist(1).join(' ');

          extractedItems.add({
            'article': article,
            'noun': noun,
            'translation': translation,
            'lesson': title,
          });
        }
      }
    }

    // تصادفی کردن ترتیب کلمات برای تنوع بیشتر
    extractedItems.shuffle();

    setState(() {
      _activeItems = extractedItems;
      _currentIndex = 0;
      _feedbackMessage = null;
    });
  }

  void _checkAnswer(String selectedArticle) {
    if (_activeItems.isEmpty) return;

    final correctAnswer = _activeItems[_currentIndex]['article'];
    setState(() {
      if (selectedArticle == correctAnswer) {
        _score += 10;
        _feedbackMessage = 'Richtig! ✅ (+10 XP)';
        _feedbackColor = Colors.greenAccent;
      } else {
        _feedbackMessage = 'Falsch! ❌ (Richtig: ${correctAnswer?.toUpperCase()})';
        _feedbackColor = Colors.redAccent;
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = null;
        if (_currentIndex < _activeItems.length - 1) {
          _currentIndex++;
        } else {
          // دور تمام شد؛ دوباره شافل و از اول
          _currentIndex = 0;
          _activeItems.shuffle();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // لیست عناوین درس‌ها برای Dropdown
    final List<String> lessonOptions = [
      'Alle',
      ...AppData.lessons.map((e) => e['title'] as String),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Artikel Trainer', style: TextStyle(color: Colors.white)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Score: $_score XP',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFFFCC00),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // بخش انتخاب درس (Lesson Selector)
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
                        _loadItemsForSelectedLesson();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),

            // کارت نمایش کلمه
            if (_activeItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(30),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // بج نشان‌دهنده درس مربوطه
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _activeItems[_currentIndex]['lesson'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '___ ${_activeItems[_currentIndex]['noun']}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(${_activeItems[_currentIndex]['translation']})',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // شمارنده کلمات
              Text(
                'کلمه ${_currentIndex + 1} از ${_activeItems.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ] else ...[
              const Center(
                child: Text(
                  'هیچ اسم با ارتیکلی در این درس یافت نشد!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],

            const Spacer(),

            // پیام بازخورد (درست/نادرست)
            SizedBox(
              height: 30,
              child: _feedbackMessage != null
                  ? Text(
                      _feedbackMessage!,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _feedbackColor),
                    )
                  : null,
            ),
            const SizedBox(height: 20),

            // دکمه‌های DER / DIE / DAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildArticleButton('DER', 'der', Colors.blue[800]!),
                _buildArticleButton('DIE', 'die', Colors.pink[800]!),
                _buildArticleButton('DAS', 'das', Colors.amber[800]!, textColor: Colors.black),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleButton(String label, String value, Color color, {Color textColor = Colors.white}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_feedbackMessage == null && _activeItems.isNotEmpty)
              ? () => _checkAnswer(value)
              : null,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
          ),
        ),
      ),
    );
  }
}