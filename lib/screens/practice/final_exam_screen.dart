import 'package:flutter/material.dart';

class FinalExamScreen extends StatefulWidget {
  const FinalExamScreen({super.key});

  @override
  State<FinalExamScreen> createState() => _FinalExamScreenState();
}

class _FinalExamScreenState extends State<FinalExamScreen> {
  int _currentQuestion = 0;
  int _score = 0;
  bool _isSubmitted = false;
  int? _selectedAnswer;

  final List<Map<String, dynamic>> _examQuestions = [
    {
      'question': 'معنی کلمه "der Vorname" چیست؟',
      'options': ['نام خانوادگی', 'نام', 'شغل', 'کشور'],
      'answer': 1,
    },
    {
      'question': 'جمله "Ich ___ aus dem Iran" را کامل کنید.',
      'options': ['komme', 'kommt', 'heiße', 'wohne'],
      'answer': 0,
    },
    {
      'question': 'کدام شغل برای یک خانم استفاده می‌شود؟',
      'options': ['der Arzt', 'die Journalistin', 'der Lehrer', 'der Verkäufer'],
      'answer': 1,
    },
    {
      'question': 'آرتیکل صحیح کلمه "Tisch" کدام است؟',
      'options': ['die', 'das', 'der', 'den'],
      'answer': 2,
    },
    {
      'question': 'معادل عبارت "خانواده من بزرگ است" کدام است؟',
      'options': ['Meine Familie ist klein.', 'Meine Familie ist groß.', 'Das ist meine Mutter.', 'Ich habe keine Familie.'],
      'answer': 1,
    },
    {
      'question': 'منفی کلمه "ein Buch" کدام است؟',
      'options': ['kein Buch', 'keine Buch', 'nicht Buch', 'keinen Buch'],
      'answer': 0,
    },
    {
      'question': 'شکل صحیح فعل "می‌توانم" (ich) از مصدر können کدام است؟',
      'options': ['kannst', 'können', 'kann', 'könnt'],
      'answer': 2,
    },
    {
      'question': 'آرتیکل صحیح کلمه "Brille" چیست؟',
      'options': ['der', 'das', 'die', 'den'],
      'answer': 2,
    },
    {
      'question': 'برای بیان روزهای هفته از کدام حرف اضافه استفاده می‌شود؟',
      'options': ['um', 'am', 'in', 'aus'],
      'answer': 1,
    },
    {
      'question': 'معنی کلمه "möchten" چیست؟',
      'options': ['نوشیدن', 'خوردن', 'مایل بودن / خواستن', 'آمدن'],
      'answer': 2,
    },
    {
      'question': 'فعل "einsteigen" چه نوع فعلی است؟',
      'options': ['فعل مدال (Modal)', 'فعل جداشدنی (Trennbar)', 'فعل ساده', 'فعل گذشته (Perfekt)'],
      'answer': 1,
    },
    {
      'question': 'گذشته فعل arbeiten در زمان Perfekt کدام است؟',
      'options': ['gearbeitet', 'gearbeiten', 'gearbeitet haben', 'gearbeitet sein'],
      'answer': 0,
    },
    {
      'question': 'کدام کلمه به معنی "ایستگاه قطار" است؟',
      'options': ['der Flughafen', 'der Bahnhof', 'die Haltestelle', 'das Auto'],
      'answer': 1,
    },
    {
      'question': 'جمله "Ich habe meinen Schlüssel ___" را کامل کنید.',
      'options': ['verloren', 'passiert', 'gegangen', 'geblieben'],
      'answer': 0,
    },
    {
      'question': 'برای پرسیدن ساعت دقیق (مثلاً ۸:۰۰) از کدام حرف اضافه استفاده می‌شود؟',
      'options': ['am', 'um', 'aus', 'mit'],
      'answer': 1,
    },
    {
      'question': 'جمع کلمه "das Kind" کدام است؟',
      'options': ['die Kinder', 'die Kindes', 'die Kind', 'der Kinder'],
      'answer': 0,
    },
    {
      'question': 'معنی کلمه "kaputt" چیست؟',
      'options': ['جدید', 'زیبا', 'خراب', 'گران'],
      'answer': 2,
    },
    {
      'question': 'کدام گزینه پاسخ مناسب برای "Wie alt bist du?" است؟',
      'options': ['Ich wohne in Teheran.', 'Ich bin 19 Jahre alt.', 'Ich bin Student.', 'Ich komme aus Iran.'],
      'answer': 1,
    },
    {
      'question': 'در Akkusativ، آرتیکل "der Tisch" به چه چیزی تبدیل می‌شود؟',
      'options': ['das Tisch', 'die Tisch', 'den Tisch', 'dem Tisch'],
      'answer': 2,
    },
    {
      'question': 'معادل "چیزی خوردن" در زبان آلمانی چیست؟',
      'options': ['etwas trinken', 'etwas essen', 'etwas kochen', 'etwas machen'],
      'answer': 1,
    },
  ];

  void _selectAnswer(int index) {
    if (_selectedAnswer != null) return;
    setState(() {
      _selectedAnswer = index;
      if (index == _examQuestions[_currentQuestion]['answer']) {
        _score += 5;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _examQuestions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedAnswer = null;
      });
    } else {
      setState(() {
        _isSubmitted = true;
      });
    }
  }

  void _restartExam() {
    setState(() {
      _currentQuestion = 0;
      _score = 0;
      _isSubmitted = false;
      _selectedAnswer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSubmitted ? 'نتیجه آزمون' : 'سوال ${_currentQuestion + 1} از ${_examQuestions.length}'),
      ),
      body: _isSubmitted ? _buildResultScreen() : _buildQuizBody(),
    );
  }

  Widget _buildQuizBody() {
    final q = _examQuestions[_currentQuestion];
    final double progress = (_currentQuestion + 1) / _examQuestions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            color: const Color(0xFFFFCC00),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.3)),
            ),
            child: Text(
              q['question'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),

          ...List.generate(q['options'].length, (index) {
            Color btnColor = const Color(0xFF1A1A1A);
            Color textColor = Colors.white;

            if (_selectedAnswer != null) {
              if (index == q['answer']) {
                btnColor = Colors.green[800]!;
              } else if (index == _selectedAnswer) {
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
                  side: BorderSide(color: _selectedAnswer == index ? const Color(0xFFFFCC00) : Colors.white10),
                ),
                onPressed: () => _selectAnswer(index),
                child: Text(
                  q['options'][index],
                  style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),

          const Spacer(),

          if (_selectedAnswer != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _nextQuestion,
                child: Text(
                  _currentQuestion == _examQuestions.length - 1 ? 'مشاهده نتیجه' : 'سوال بعدی →',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final bool isPassed = _score >= 70;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPassed ? Icons.workspace_premium : Icons.sentiment_dissatisfied,
              size: 100,
              color: isPassed ? const Color(0xFFFFCC00) : Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              isPassed ? 'تبریک! آزمون را با موفقیت پاس کردی 🎉' : 'متأسفانه حد نصاب قبولی را کسب نکردی',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'نمره شما: $_score از ۱۰۰',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isPassed ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPassed ? 'حد نصاب قبولی: ۷۰ | نمره عالی!' : 'حد نصاب قبولی: ۷۰ | دوباره تلاش کن!',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: _restartExam,
              child: const Text('شروع مجدد آزمون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}