import 'package:flutter/material.dart';
import '../services/learn_data_store.dart';
import '../models/learn_models.dart';

class AdminQuizQuestionsScreen extends StatefulWidget {
  final QuizEvent event;

  const AdminQuizQuestionsScreen({super.key, required this.event});

  @override
  State<AdminQuizQuestionsScreen> createState() => _AdminQuizQuestionsScreenState();
}

class _AdminQuizQuestionsScreenState extends State<AdminQuizQuestionsScreen> {
  final _store = LearnDataStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quiz Questions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.event.title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Column(
            children: [
              // Stats
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.event.color.withAlpha((0.2 * 255).round()),
                      widget.event.color.withAlpha((0.1 * 255).round()),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.event.color.withAlpha((0.3 * 255).round()),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Questions',
                      '${widget.event.questions.length}',
                      Icons.quiz,
                    ),
                    _buildStatItem(
                      'Total Points',
                      '${widget.event.questions.fold<int>(0, (sum, q) => sum + q.points)}',
                      Icons.stars,
                    ),
                    _buildStatItem(
                      'Avg Time',
                      '${widget.event.questions.isEmpty ? 0 : (widget.event.questions.fold<int>(0, (sum, q) => sum + q.timeLimit) / widget.event.questions.length).toStringAsFixed(0)}s',
                      Icons.timer,
                    ),
                  ],
                ),
              ),
              
              // Questions List
              Expanded(
                child: widget.event.questions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.quiz_outlined,
                              size: 64,
                              color: Colors.white.withAlpha((0.3 * 255).round()),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No questions yet',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap + to add your first question',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.event.questions.length,
                        itemBuilder: (context, index) {
                          final question = widget.event.questions[index];
                          return _buildQuestionCard(question, index);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddQuestionDialog,
        backgroundColor: widget.event.color,
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: widget.event.color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(QuizQuestion question, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((0.1 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.event.color.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: TextStyle(
                    color: widget.event.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF00BFA5)),
                onPressed: () => _showEditQuestionDialog(question),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteQuestion(question),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final option = entry.value;
            final isCorrect = i == question.correctAnswerIndex;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withAlpha((0.2 * 255).round())
                    : Colors.white.withAlpha((0.05 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green
                      : Colors.white.withAlpha((0.1 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  if (isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  if (isCorrect) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        color: isCorrect ? Colors.white : Colors.white70,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.score, '${question.points} pts'),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.timer, '${question.timeLimit}s'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog() {
    final questionController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    final pointsController = TextEditingController(text: '10');
    final timeLimitController = TextEditingController(text: '30');
    int correctAnswerIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Question', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Enter your question here...',
                    hintStyle: TextStyle(color: Colors.white30),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Answer Options:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // ignore: deprecated_member_use
                        Radio<int>(
                          value: i,
                          // ignore: deprecated_member_use
                          groupValue: correctAnswerIndex,
                          // ignore: deprecated_member_use
                          onChanged: (value) {
                            setDialogState(() => correctAnswerIndex = value!);
                          },
                          activeColor: Colors.green,
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[i],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Option ${String.fromCharCode(65 + i)}',
                              labelStyle: const TextStyle(color: Colors.white70),
                              hintText: 'Enter option...',
                              hintStyle: const TextStyle(color: Colors.white30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: timeLimitController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Time (seconds)',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if (questionController.text.isEmpty) return;
                if (optionControllers.any((c) => c.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all answer options'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final newQuestion = QuizQuestion(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  question: questionController.text,
                  options: optionControllers.map((c) => c.text).toList(),
                  correctAnswerIndex: correctAnswerIndex,
                  points: int.tryParse(pointsController.text) ?? 10,
                  timeLimit: int.tryParse(timeLimitController.text) ?? 30,
                );

                widget.event.questions.add(newQuestion);
                _store.updateEvent(widget.event);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.event.color,
              ),
              child: const Text('Add Question'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuestionDialog(QuizQuestion question) {
    final questionController = TextEditingController(text: question.question);
    final optionControllers = question.options.map((o) => TextEditingController(text: o)).toList();
    final pointsController = TextEditingController(text: question.points.toString());
    final timeLimitController = TextEditingController(text: question.timeLimit.toString());
    int correctAnswerIndex = question.correctAnswerIndex;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Question', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // ignore: deprecated_member_use
                        Radio<int>(
                          value: i,
                          // ignore: deprecated_member_use
                          groupValue: correctAnswerIndex,
                          // ignore: deprecated_member_use
                          onChanged: (value) {
                            setDialogState(() => correctAnswerIndex = value!);
                          },
                          activeColor: Colors.green,
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[i],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Option ${String.fromCharCode(65 + i)}',
                              labelStyle: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: timeLimitController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Time (seconds)',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                question.question = questionController.text;
                question.options = optionControllers.map((c) => c.text).toList();
                question.correctAnswerIndex = correctAnswerIndex;
                question.points = int.tryParse(pointsController.text) ?? 10;
                question.timeLimit = int.tryParse(timeLimitController.text) ?? 30;

                _store.updateEvent(widget.event);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.event.color,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteQuestion(QuizQuestion question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Question?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this question?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.event.questions.remove(question);
              _store.updateEvent(widget.event);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
