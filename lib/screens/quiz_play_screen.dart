import 'package:flutter/material.dart';
import '../models/learn_models.dart';

class QuizSessionResult {
  final int score;
  final int maxScore;
  final int correctAnswers;
  final int totalQuestions;

  const QuizSessionResult({
    required this.score,
    required this.maxScore,
    required this.correctAnswers,
    required this.totalQuestions,
  });
}

class QuizPlayScreen extends StatefulWidget {
  final QuizEvent event;

  const QuizPlayScreen({super.key, required this.event});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late final List<QuizQuestion> _questions = widget.event.questions;
  late final List<int?> _answers = List<int?>.filled(_questions.length, null);
  int _currentIndex = 0;
  bool _showSummary = false;

  Color get _accent => widget.event.color;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0A1628);

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: _questions.isEmpty
          ? _buildEmptyState()
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showSummary ? _buildSummary() : _buildQuestionView(),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F1E30),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white70),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Quiz session',
            style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round()), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 72, color: Colors.white.withAlpha((0.25 * 255).round())),
            const SizedBox(height: 18),
            const Text(
              'This quiz is not ready yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check back soon once the admin has published the questions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    final question = _questions[_currentIndex];
    final selected = _answers[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Padding(
      key: ValueKey(_currentIndex),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withAlpha((0.08 * 255).round()),
            valueColor: AlwaysStoppedAnimation<Color>(_accent),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).round()),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentIndex + 1} of ${_questions.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  question.question,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.white.withAlpha((0.6 * 255).round())),
                    const SizedBox(width: 6),
                    Text(
                      '${question.timeLimit}s • ${question.points} pts',
                      style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round()), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) => _buildOptionTile(question, index, selected),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.6),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: selected == null ? _showMissingSelection : _advance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_currentIndex == _questions.length - 1 ? 'Finish' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(QuizQuestion question, int index, int? selected) {
    final isSelected = selected == index;
    final letter = String.fromCharCode(65 + index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectOption(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected
                  ? _accent.withAlpha((0.25 * 255).round())
                  : Colors.white.withAlpha((0.05 * 255).round()),
              border: Border.all(
                color: isSelected
                    ? _accent
                    : Colors.white.withAlpha((0.08 * 255).round()),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withAlpha((0.08 * 255).round()),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: isSelected ? _accent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.options[index],
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final correct = _calculateCorrectAnswers();
    final maxScore = _calculateMaximumScore();
    final score = _calculateScore();

    return Padding(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  _accent.withAlpha((0.24 * 255).round()),
                  _accent.withAlpha((0.14 * 255).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _accent.withAlpha((0.6 * 255).round())),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha((0.15 * 255).round()),
                  ),
                  child: const Icon(Icons.stars, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: $score / $maxScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Correct answers: $correct / ${_questions.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];
                final selected = _answers[index];
                final isCorrect = selected == question.correctAnswerIndex;
                final indicatorColor = isCorrect ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
                final correctAnswer = question.options[question.correctAnswerIndex];
                final selectedAnswer = selected != null ? question.options[selected] : 'No answer';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: indicatorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              question.question,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your answer: $selectedAnswer',
                        style: TextStyle(
                          color: isCorrect ? Colors.white70 : const Color(0xFFEF9A9A),
                          fontSize: 13,
                        ),
                      ),
                      if (!isCorrect)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Correct answer: $correctAnswer',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final result = QuizSessionResult(
                score: score,
                maxScore: maxScore,
                correctAnswers: correct,
                totalQuestions: _questions.length,
              );
              Navigator.pop(context, result);
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finish review'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  void _selectOption(int index) {
    setState(() {
      _answers[_currentIndex] = index;
    });
  }

  void _advance() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex += 1;
      });
    } else {
      setState(() {
        _showSummary = true;
      });
    }
  }

  void _showMissingSelection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select an answer before continuing.'),
        backgroundColor: Color(0xFFEF5350),
      ),
    );
  }

  int _calculateCorrectAnswers() {
    var count = 0;
    for (var i = 0; i < _questions.length; i++) {
      final selected = _answers[i];
      if (selected != null && selected == _questions[i].correctAnswerIndex) {
        count += 1;
      }
    }
    return count;
  }

  int _calculateMaximumScore() {
    return _questions.fold<int>(0, (sum, question) => sum + question.points);
  }

  int _calculateScore() {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      final selected = _answers[i];
      if (selected != null && selected == _questions[i].correctAnswerIndex) {
        score += _questions[i].points;
      }
    }
    return score;
  }
}
