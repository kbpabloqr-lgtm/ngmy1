import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/learn_models.dart';
import '../../services/learn_data_store.dart';

Future<void> showScrambleGameSheet(
  BuildContext context,
  TranslatorWordGame game,
  LearnDataStore store,
) async {
  final random = math.Random();
  var sessionPrompts = List<TranslatorWordGamePrompt>.from(game.prompts)
    ..shuffle(random);
  if (sessionPrompts.isEmpty) {
    return;
  }

  final totalRounds = sessionPrompts.length;
  int currentIndex = 0;
  int score = 0;
  bool sessionComplete = false;
  bool resultRecorded = false;

  List<String> letterBank = <String>[];
  List<bool> letterUsed = <bool>[];
  List<int> slotAssignments = <int>[];
  bool roundSolved = false;
  bool showHint = false;
  String feedback = '';

  void configureRound() {
    final prompt = sessionPrompts[currentIndex];
    letterBank = _buildScrambleLetterBank(prompt.term, random);
    if (letterBank.isEmpty) {
      letterBank = _scrambleLetters(prompt.term);
    }
    if (letterBank.isEmpty) {
      letterBank = <String>['?'];
    }
    letterUsed = List<bool>.filled(letterBank.length, false);
    slotAssignments = List<int>.filled(letterBank.length, -1);
    roundSolved = false;
    showHint = false;
    feedback = '';
  }

  void resetSession() {
    sessionPrompts = List<TranslatorWordGamePrompt>.from(game.prompts)
      ..shuffle(random);
    currentIndex = 0;
    configureRound();
  }

  configureRound();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071020),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final prompt = sessionPrompts[currentIndex];

          String composeGuess() {
            if (slotAssignments.contains(-1)) {
              return '';
            }
            final buffer = StringBuffer();
            for (final index in slotAssignments) {
              if (index < 0 || index >= letterBank.length) {
                return '';
              }
              buffer.write(letterBank[index]);
            }
            return buffer.toString();
          }

          void fillNextSlot(int bankIndex) {
            if (sessionComplete || roundSolved) {
              return;
            }
            if (bankIndex < 0 || bankIndex >= letterBank.length) {
              return;
            }
            if (letterUsed[bankIndex]) {
              return;
            }
            final slotIndex = slotAssignments.indexOf(-1);
            if (slotIndex == -1) {
              return;
            }
            setSheetState(() {
              slotAssignments[slotIndex] = bankIndex;
              letterUsed[bankIndex] = true;
              feedback = '';
            });
          }

          void removeSlot(int slotIndex) {
            if (sessionComplete || roundSolved) {
              return;
            }
            if (slotIndex < 0 || slotIndex >= slotAssignments.length) {
              return;
            }
            final bankIndex = slotAssignments[slotIndex];
            if (bankIndex == -1) {
              return;
            }
            setSheetState(() {
              slotAssignments[slotIndex] = -1;
              if (bankIndex >= 0 && bankIndex < letterUsed.length) {
                letterUsed[bankIndex] = false;
              }
              feedback = '';
            });
          }

          void clearSlots() {
            if (sessionComplete || roundSolved) {
              return;
            }
            setSheetState(() {
              slotAssignments = List<int>.filled(letterBank.length, -1);
              letterUsed = List<bool>.filled(letterBank.length, false);
              feedback = '';
            });
          }

          void shuffleTiles() {
            if (sessionComplete || roundSolved) {
              return;
            }
            setSheetState(() {
              letterBank = List<String>.from(letterBank)..shuffle(random);
              slotAssignments = List<int>.filled(letterBank.length, -1);
              letterUsed = List<bool>.filled(letterBank.length, false);
              feedback = '';
            });
          }

          void revealSolution() {
            if (sessionComplete || roundSolved) {
              return;
            }
            final solutionLetters = _scrambleLetters(_expectedAnswerForPrompt(prompt));
            final used = List<bool>.filled(letterBank.length, false);
            final assignments = List<int>.filled(letterBank.length, -1);
            for (var i = 0; i < solutionLetters.length && i < assignments.length; i++) {
              final letter = solutionLetters[i];
              var found = -1;
              for (var j = 0; j < letterBank.length; j++) {
                if (!used[j] && letterBank[j] == letter) {
                  found = j;
                  break;
                }
              }
              if (found != -1) {
                assignments[i] = found;
                used[found] = true;
              }
            }
            setSheetState(() {
              slotAssignments = assignments;
              letterUsed = used;
              roundSolved = true;
              feedback = 'Solution: ${_expectedAnswerForPrompt(prompt)}';
            });
          }

          Future<void> submitGuess() async {
            if (sessionComplete || roundSolved) {
              return;
            }
            final guess = composeGuess();
            if (guess.isEmpty) {
              setSheetState(() {
                feedback = 'Use every tile to build the word.';
              });
              return;
            }
            final correct = _isCorrectAnswer(prompt, guess);
            setSheetState(() {
              if (correct && !roundSolved) {
                score += 1;
              }
              roundSolved = correct;
              feedback = correct
                  ? _positiveFeedback(random)
                  : 'Not quite. Shuffle the tiles and try again.';
            });
          }

          Future<void> finishSession() async {
            if (sessionComplete) {
              return;
            }
            setSheetState(() {
              sessionComplete = true;
            });
            if (!resultRecorded) {
              resultRecorded = true;
              await store.recordWordGameResult(
                gameId: game.id,
                score: score,
                total: totalRounds,
              );
            }
          }

          Future<void> goToNext() async {
            if (sessionComplete) {
              return;
            }
            if (!roundSolved) {
              await submitGuess();
              if (!roundSolved) {
                return;
              }
            }
            if (currentIndex < totalRounds - 1) {
              setSheetState(() {
                currentIndex += 1;
                configureRound();
              });
            } else {
              await finishSession();
            }
          }

          void skipRound() {
            if (sessionComplete) {
              return;
            }
            if (!roundSolved) {
              revealSolution();
              setSheetState(() {
                feedback = 'Solution: ${_expectedAnswerForPrompt(prompt)}. Tap Next puzzle to continue.';
              });
            }
          }

          void replaySession() {
            setSheetState(() {
              score = 0;
              sessionComplete = false;
              resultRecorded = false;
              resetSession();
            });
          }

          final progress = (currentIndex + 1) / totalRounds;
          final tileCount = letterBank.length;

          Widget buildHandle() {
            return Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHandle(),
              const SizedBox(height: 18),
              if (!sessionComplete) ...[
                Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Puzzle ${currentIndex + 1} of $totalRounds',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    Text(
                      'Score $score',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF26C6DA),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                if (_hasPromptScreenshot(prompt)) ...[
                  _PromptScreenshotCard(
                    source: prompt.screenshotImageUrl!.trim(),
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(tileCount, (index) {
                    final bankIndex = index < slotAssignments.length
                        ? slotAssignments[index]
                        : -1;
                    final letter = (bankIndex >= 0 && bankIndex < letterBank.length)
                        ? letterBank[bankIndex]
                        : '';
                    final activeColor = roundSolved
                        ? const Color(0xFF00BFA5).withAlpha(200)
                        : Colors.white.withAlpha(letter.isEmpty ? 40 : 240);
                    return GestureDetector(
                      onTap: (letter.isEmpty || sessionComplete || roundSolved)
                          ? null
                          : () => removeSlot(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 58,
                        height: 64,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: roundSolved
                                ? const Color(0xFF00BFA5)
                                : Colors.white24,
                            width: 1.4,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: TextStyle(
                            color: roundSolved
                                ? Colors.black
                                : (letter.isEmpty ? Colors.white38 : Colors.black),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(letterBank.length, (index) {
                    final letter = letterBank[index];
                    final used = letterUsed[index];
                    final disabled = used || sessionComplete || roundSolved;
                    return Material(
                      color:
                          disabled ? Colors.white10 : Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: disabled ? null : () => fillNextSlot(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: disabled ? Colors.white38 : Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    feedback,
                    style: TextStyle(
                      color: roundSolved
                          ? const Color(0xFF00BFA5)
                          : const Color(0xFFFF8A65),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: sessionComplete
                            ? null
                            : (roundSolved ? goToNext : submitGuess),
                        icon: Icon(roundSolved
                            ? (currentIndex == totalRounds - 1
                                ? Icons.flag
                                : Icons.arrow_forward)
                            : Icons.check),
                        label: Text(roundSolved
                            ? (currentIndex == totalRounds - 1
                                ? 'Finish'
                                : 'Next puzzle')
                            : 'Check word'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26C6DA),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sessionComplete || roundSolved
                            ? null
                            : shuffleTiles,
                        icon: const Icon(Icons.shuffle, color: Colors.white70),
                        label: const Text('Shuffle tiles',
                            style: TextStyle(color: Colors.white70)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sessionComplete || roundSolved
                            ? null
                            : clearSlots,
                        icon: const Icon(Icons.backspace_outlined,
                            color: Colors.white70),
                        label: const Text('Clear',
                            style: TextStyle(color: Colors.white70)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: sessionComplete ? null : skipRound,
                      icon: const Icon(Icons.visibility,
                          color: Colors.white70, size: 18),
                      label: const Text('Reveal answer',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    if (prompt.hint != null && prompt.hint!.trim().isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            showHint = !showHint;
                          });
                        },
                        icon: Icon(
                          showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                          color: const Color(0xFFFFB300),
                          size: 18,
                        ),
                        label: Text(
                          showHint ? 'Hide hint' : 'Show hint',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (showHint &&
                    prompt.hint != null &&
                    prompt.hint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prompt.hint!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration,
                          color: Color(0xFF00BFA5), size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'Words solved: $score / $totalRounds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Solution: ${_expectedAnswerForPrompt(prompt)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: replaySession,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Play again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF26C6DA),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          label: const Text('Close',
                              style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: body,
            ),
          );
        },
      );
    },
  );
}

Future<void> showWordleGameSheet(
  BuildContext context,
  TranslatorWordGame game,
  LearnDataStore store,
) async {
  final random = math.Random();
  var prompts = List<TranslatorWordGamePrompt>.from(game.prompts)
    ..shuffle(random);
  prompts = prompts
      .where((prompt) => _normalizeWordleTarget(prompt.term).length >= 3)
      .toList();
  if (prompts.isEmpty) {
    return;
  }

  const maxAttempts = 6;
  int promptIndex = 0;
  late TranslatorWordGamePrompt activePrompt;
  late String solution;

  List<String> guesses = <String>[];
  List<List<_WordleTileStatus>> guessStatuses = <List<_WordleTileStatus>>[];
  Map<String, _WordleKeyStatus> keyStates = <String, _WordleKeyStatus>{};
  String currentGuess = '';
  bool sessionComplete = false;
  bool resultRecorded = false;
  bool solved = false;
  int sessionScore = 0;
  String feedback = '';
  bool showHint = false;

  void prepareRound({bool reshuffle = false}) {
    if (reshuffle || promptIndex >= prompts.length) {
      prompts.shuffle(random);
      promptIndex = 0;
    }
    activePrompt = prompts[promptIndex];
    promptIndex += 1;
    solution = _normalizeWordleTarget(activePrompt.term);
    guesses = <String>[];
    guessStatuses = <List<_WordleTileStatus>>[];
    keyStates = <String, _WordleKeyStatus>{};
    currentGuess = '';
    sessionComplete = false;
    resultRecorded = false;
    solved = false;
    sessionScore = 0;
    feedback = '';
    showHint = false;
  }

  prepareRound();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071020),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final wordLength = solution.length;

          void addLetter(String letter) {
            if (sessionComplete) {
              return;
            }
            if (currentGuess.length >= wordLength) {
              return;
            }
            setSheetState(() {
              currentGuess = (currentGuess + letter).toUpperCase();
              feedback = '';
            });
          }

          void removeLetter() {
            if (sessionComplete || currentGuess.isEmpty) {
              return;
            }
            setSheetState(() {
              currentGuess = currentGuess.substring(0, currentGuess.length - 1);
              feedback = '';
            });
          }

          Future<void> submitGuess() async {
            if (sessionComplete) {
              return;
            }
            if (currentGuess.length < wordLength) {
              setSheetState(() {
                feedback = 'Use $wordLength letters before submitting.';
              });
              return;
            }
            final guess = currentGuess.toUpperCase();
            final statuses = _evaluateWordleGuess(guess, solution);
            setSheetState(() {
              guesses = [...guesses, guess];
              guessStatuses = [...guessStatuses, statuses];
              currentGuess = '';
              for (var i = 0; i < guess.length; i++) {
                final letter = guess[i];
                final status = statuses[i];
                final keyStatus = switch (status) {
                  _WordleTileStatus.correct => _WordleKeyStatus.correct,
                  _WordleTileStatus.present => _WordleKeyStatus.present,
                  _WordleTileStatus.miss => _WordleKeyStatus.miss,
                  _WordleTileStatus.empty => _WordleKeyStatus.unused,
                };
                _updateWordleKeyStatus(keyStates, letter, keyStatus);
              }
            });

            final correct = _isCorrectAnswer(activePrompt, guess);
            if (correct) {
              setSheetState(() {
                solved = true;
                sessionComplete = true;
                feedback = _positiveFeedback(random);
              });
            } else if (guesses.length >= maxAttempts) {
              setSheetState(() {
                sessionComplete = true;
                feedback = 'The word was ${activePrompt.term.toUpperCase()}.';
              });
            }

            if (sessionComplete && !resultRecorded) {
              resultRecorded = true;
              final computedScore = solved ? (maxAttempts - guesses.length + 1) : 0;
              sessionScore = computedScore;
              await store.recordWordGameResult(
                gameId: game.id,
                score: computedScore,
                total: maxAttempts,
              );
            }
          }

          void replaySession() {
            setSheetState(() {
              prepareRound(reshuffle: true);
            });
          }

          Widget buildHandle() {
            return Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }

          Widget buildTile(int rowIndex, int letterIndex) {
            String display = '';
            _WordleTileStatus status = _WordleTileStatus.empty;
            if (rowIndex < guessStatuses.length) {
              display = guesses[rowIndex][letterIndex];
              status = guessStatuses[rowIndex][letterIndex];
            } else if (rowIndex == guessStatuses.length &&
                letterIndex < currentGuess.length) {
              display = currentGuess[letterIndex];
            }
            return Container(
              width: 54,
              height: 58,
              decoration: BoxDecoration(
                color: _wordleTileColor(status),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _wordleTileBorder(status), width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          Widget buildKey(String label) {
            if (label == 'ENTER') {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ElevatedButton(
                    onPressed: sessionComplete ? null : submitGuess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26C6DA),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Enter',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            }
            if (label == 'BACK') {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ElevatedButton(
                    onPressed: sessionComplete ? null : removeLetter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.backspace_outlined),
                  ),
                ),
              );
            }

            final letter = label.toUpperCase();
            final status = keyStates[letter] ?? _WordleKeyStatus.unused;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: ElevatedButton(
                  onPressed: sessionComplete ? null : () => addLetter(letter),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _wordleKeyColor(status),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }

          const keyboardLayout = [
            ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
            ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
            ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'BACK'],
          ];

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHandle(),
              const SizedBox(height: 18),
              if (!sessionComplete) ...[
                Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Attempt ${guesses.length + 1} of $maxAttempts',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_hasPromptScreenshot(activePrompt)) ...[
                  _PromptScreenshotCard(
                    source: activePrompt.screenshotImageUrl!.trim(),
                  ),
                  const SizedBox(height: 18),
                ],
                Column(
                  children: List.generate(maxAttempts, (row) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          wordLength,
                          (col) => buildTile(row, col),
                        ),
                      ),
                    );
                  }),
                ),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    feedback,
                    style: TextStyle(
                      color: solved
                          ? const Color(0xFF00BFA5)
                          : const Color(0xFFFF8A65),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (activePrompt.hint != null &&
                    activePrompt.hint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setSheetState(() {
                        showHint = !showHint;
                      });
                    },
                    icon: Icon(
                      showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                      color: const Color(0xFFFFB300),
                      size: 18,
                    ),
                    label: Text(
                      showHint ? 'Hide hint' : 'Need a hint?',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  if (showHint) ...[
                    const SizedBox(height: 4),
                    Text(
                      activePrompt.hint!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                for (final row in keyboardLayout)
                  Row(
                    children: row.map(buildKey).toList(),
                  ),
              ] else ...[
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        solved ? Icons.emoji_events : Icons.quiz_outlined,
                        color: solved
                            ? const Color(0xFF00BFA5)
                            : const Color(0xFFFFB300),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        solved
                            ? 'You cracked it in ${guesses.length} tries!'
                            : 'Word escaped today.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Word: ${activePrompt.term.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        solved
                            ? 'Quest score: $sessionScore'
                            : 'Try again soon for a new glow word.',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: replaySession,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Play again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF26C6DA),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          label: const Text('Close',
                              style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: body,
            ),
          );
        },
      );
    },
  );
}

bool _isCorrectAnswer(TranslatorWordGamePrompt prompt, String answer) {
  final normalized = _normalizeAnswer(answer);
  if (normalized.isEmpty) {
    return false;
  }
  final accepted = _answerSetForPrompt(prompt);
  return accepted.contains(normalized);
}

String _normalizeAnswer(String value) {
  final lower = value.trim().toLowerCase();
  return lower.replaceAll(RegExp(r'\s+'), ' ');
}

Set<String> _answerSetForPrompt(TranslatorWordGamePrompt prompt) {
  final set = <String>{};

  void addValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return;
    }
    final fragments = value.split(RegExp(r'[;,/|]'));
    if (fragments.length == 1) {
      set.add(_normalizeAnswer(value));
    } else {
      for (final fragment in fragments) {
        if (fragment.trim().isEmpty) continue;
        set.add(_normalizeAnswer(fragment));
      }
    }
  }

  if (prompt.type == 'translation') {
    addValue(prompt.translation);
    for (final alt in prompt.alternateAnswers) {
      addValue(alt);
    }
    if (set.isEmpty) {
      addValue(prompt.term);
    }
  } else {
    addValue(prompt.term);
    addValue(prompt.translation);
    for (final alt in prompt.alternateAnswers) {
      addValue(alt);
    }
  }

  return set;
}

String _expectedAnswerForPrompt(TranslatorWordGamePrompt prompt) {
  if (prompt.type == 'translation') {
    if (prompt.translation.trim().isNotEmpty) {
      return prompt.translation;
    }
    if (prompt.alternateAnswers.isNotEmpty) {
      return prompt.alternateAnswers.first;
    }
  }
  if (prompt.type == 'sentence') {
    if (prompt.term.trim().isNotEmpty) {
      return prompt.term;
    }
  }
  if (prompt.term.trim().isNotEmpty) {
    return prompt.term;
  }
  return prompt.translation.isNotEmpty
      ? prompt.translation
      : prompt.alternateAnswers.join(', ');
}

String _positiveFeedback(math.Random random) {
  const responses = [
    'Great job!',
    'Nice work!',
    'You nailed it!',
    'Brilliant answer!',
    'Keep going!',
  ];
  return responses[random.nextInt(responses.length)];
}

bool _hasPromptScreenshot(TranslatorWordGamePrompt prompt) {
  final value = prompt.screenshotImageUrl;
  return value != null && value.trim().isNotEmpty;
}

class _PromptScreenshotCard extends StatelessWidget {
  const _PromptScreenshotCard({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget image;
    if (_isNetworkImage(trimmed)) {
      image = Image.network(
        trimmed,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 180,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          final expected = progress.expectedTotalBytes;
          final loaded = progress.cumulativeBytesLoaded;
          final value = expected != null && expected > 0
              ? loaded / expected
              : null;
          return SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.white54,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const _PromptScreenshotFallback(),
      );
    } else if (_isAssetImage(trimmed)) {
      image = Image.asset(
        trimmed,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 180,
        errorBuilder: (context, error, stackTrace) => const _PromptScreenshotFallback(),
      );
    } else {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: image),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Puzzle reference',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isNetworkImage(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

bool _isAssetImage(String value) => value.startsWith('assets/');

class _PromptScreenshotFallback extends StatelessWidget {
  const _PromptScreenshotFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      alignment: Alignment.center,
      color: Colors.white12,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white38,
        size: 28,
      ),
    );
  }
}

List<String> _scrambleLetters(String term) {
  final sanitized = term.replaceAll(RegExp(r'[^A-Za-z]'), '');
  final source = sanitized.isNotEmpty ? sanitized : term;
  return source
      .toUpperCase()
      .split('')
      .where((letter) => letter.trim().isNotEmpty)
      .toList();
}

List<String> _buildScrambleLetterBank(String term, math.Random random) {
  final letters = _scrambleLetters(term);
  if (letters.length <= 1) {
    return letters;
  }
  final bank = List<String>.from(letters);
  for (var attempt = 0; attempt < 6; attempt += 1) {
    bank.shuffle(random);
    var same = true;
    for (var i = 0; i < bank.length; i++) {
      if (bank[i] != letters[i]) {
        same = false;
        break;
      }
    }
    if (!same) {
      break;
    }
  }
  return bank;
}

String _normalizeWordleTarget(String term) {
  final letters = _scrambleLetters(term);
  if (letters.isEmpty) {
    return term.trim().toUpperCase();
  }
  return letters.join();
}

List<_WordleTileStatus> _evaluateWordleGuess(String guess, String solution) {
  final result =
      List<_WordleTileStatus>.filled(solution.length, _WordleTileStatus.miss);
  final solutionChars = solution.split('');
  final used = List<bool>.filled(solutionChars.length, false);
  final guessChars = guess.split('');

  for (var i = 0; i < guessChars.length && i < solutionChars.length; i++) {
    if (guessChars[i] == solutionChars[i]) {
      result[i] = _WordleTileStatus.correct;
      used[i] = true;
    }
  }

  for (var i = 0; i < guessChars.length && i < solutionChars.length; i++) {
    if (result[i] == _WordleTileStatus.correct) {
      continue;
    }
    final current = guessChars[i];
    var matchIndex = -1;
    for (var j = 0; j < solutionChars.length; j++) {
      if (!used[j] && solutionChars[j] == current) {
        matchIndex = j;
        break;
      }
    }
    if (matchIndex != -1) {
      result[i] = _WordleTileStatus.present;
      used[matchIndex] = true;
    } else {
      result[i] = _WordleTileStatus.miss;
    }
  }

  return result;
}

Color _wordleTileColor(_WordleTileStatus status) {
  switch (status) {
    case _WordleTileStatus.correct:
      return const Color(0xFF00BFA5);
    case _WordleTileStatus.present:
      return const Color(0xFFFFB300);
    case _WordleTileStatus.miss:
      return Colors.white12;
    case _WordleTileStatus.empty:
      return Colors.white10;
  }
}

Color _wordleTileBorder(_WordleTileStatus status) {
  switch (status) {
    case _WordleTileStatus.correct:
      return const Color(0xFF00BFA5);
    case _WordleTileStatus.present:
      return const Color(0xFFFFB300);
    case _WordleTileStatus.miss:
      return Colors.white24;
    case _WordleTileStatus.empty:
      return Colors.white24;
  }
}

Color _wordleKeyColor(_WordleKeyStatus status) {
  switch (status) {
    case _WordleKeyStatus.correct:
      return const Color(0xFF00BFA5);
    case _WordleKeyStatus.present:
      return const Color(0xFFFFB300);
    case _WordleKeyStatus.miss:
      return Colors.white24;
    case _WordleKeyStatus.unused:
      return Colors.white30;
  }
}

void _updateWordleKeyStatus(
  Map<String, _WordleKeyStatus> states,
  String letter,
  _WordleKeyStatus nextStatus,
) {
  final current = states[letter];
  if (current == null || nextStatus.index > current.index) {
    states[letter] = nextStatus;
  }
}

enum _WordleTileStatus { empty, miss, present, correct }

enum _WordleKeyStatus { unused, miss, present, correct }
