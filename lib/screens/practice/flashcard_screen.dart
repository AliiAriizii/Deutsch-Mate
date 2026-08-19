import 'package:flutter/material.dart';
import '../../core/utils/audio_helper.dart';
import 'package:deutsch_mate/core/constants/app_data.dart'; // مطمئن شو مسیر ایمپورت AppData متناسب با پروژه‌ات باشه

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  bool _showTranslation = false;
  int _initialTotal = 0;
  String _selectedLesson = 'Alle'; // گزینه‌ پیش‌فرض: همه درس‌ها
  late List<Map<String, String>> _cards;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  // بارگذاری و فیلتر کردن کارت‌ها از AppData
  void _loadCards() {
    List<Map<String, String>> extracted = [];

    for (var lesson in AppData.lessons) {
      final title = lesson['title'] as String? ?? '';

      if (_selectedLesson != 'Alle' && title != _selectedLesson) {
        continue;
      }

      final words = lesson['words'] as List<dynamic>? ?? [];
      for (var item in words) {
        extracted.add({
          'de': item['word'] ?? '',
          'fa': item['translation'] ?? '',
          'lesson': title,
        });
      }
    }

    // تصادفی کردن کارت‌ها برای یادگیری بهتر
    extracted.shuffle();

    setState(() {
      _cards = extracted;
      _initialTotal = _cards.length;
      _showTranslation = false;
    });
  }

  void _markAsNotLearned() {
    if (_cards.isEmpty) return;
    setState(() {
      _showTranslation = false;
      final currentCard = _cards.removeAt(0);
      _cards.add(currentCard); // کارت می‌ره ته صف تا دوباره مرور بشه
    });
  }

  void _markAsLearned() {
    if (_cards.isEmpty) return;
    setState(() {
      _showTranslation = false;
      _cards.removeAt(0); // کارت از لیست یادگیری این جلسه حذف میشه
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
          'Leitner Box (${_cards.length} کارت باقی‌مانده)',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // انتخاب درس (Dropdown)
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
                        _loadCards();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // محتوای اصلی (کارت لایتنر یا صفحه اتمام)
            Expanded(
              child: _cards.isEmpty
                  ? _buildCompletionScreen()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showTranslation = !_showTranslation),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            width: double.infinity,
                            height: 260,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFCC00)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // لیبل درس مربوطه روی کارت
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _cards[0]['lesson'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _showTranslation ? _cards[0]['fa']! : _cards[0]['de']!,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: _showTranslation ? const Color(0xFFFFCC00) : Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                if (!_showTranslation)
                                  IconButton(
                                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFCC00), size: 30),
                                    onPressed: () => AudioHelper.speakDe(_cards[0]['de']!),
                                  ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '(برای دیدن معنی روی کارت ضربه بزنید)',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[900],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _markAsNotLearned,
                                icon: const Icon(Icons.close, color: Colors.white),
                                label: const Text('بلد نبودم ❌', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _markAsLearned,
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text('بلد بودم ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, size: 90, color: Color(0xFFFFCC00)),
            const SizedBox(height: 20),
            const Text(
              'عالی بود! 🎉',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'تمام $_initialTotal لغت این جلسه را با موفقیت مرور کردی و یاد گرفتی.',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _loadCards(),
              child: const Text('شروع مجدد تمرین', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}