import 'dart:convert';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../models/learn_models.dart';
import '../services/learn_data_store.dart';
import '../widgets/floating_header.dart';
import 'admin_content_screen.dart';
import 'admin_quiz_questions_screen.dart';

class AdminLearnControlScreen extends StatefulWidget {
  const AdminLearnControlScreen({super.key});

  @override
  State<AdminLearnControlScreen> createState() =>
      _AdminLearnControlScreenState();
}

class _AdminLearnControlScreenState extends State<AdminLearnControlScreen> {
  static const _background = Color(0xFF071020);
  static const Map<String, String> _categoryBlurbs = {
    'Football Quiz': 'Legends, tactics, and rivalries in quick-fire rounds.',
    'Geography Quiz': 'Capitals, landforms, and map mastery challenges.',
    'Politics Quiz': 'Policy, elections, and leadership trivia sets.',
    'General Quiz': 'Rapid-fire knowledge checks for every topic.',
    'Map Quiz': 'Pin locations and borders faster than the pack.',
  };

  static const List<IconData> _categoryIcons = [
    Icons.quiz,
    Icons.auto_stories,
    Icons.sports_soccer,
    Icons.public,
    Icons.gavel,
    Icons.lightbulb,
    Icons.language,
    Icons.science,
    Icons.map,
    Icons.music_note,
  ];

  static const List<Color> _eventSwatches = [
    Color(0xFF00BFA5),
    Color(0xFF26C6DA),
    Color(0xFF5C6BC0),
    Color(0xFF7E57C2),
    Color(0xFFFFB300),
    Color(0xFFEF5350),
  ];

  final LearnDataStore _store = LearnDataStore.instance;

  String? _inferMimeType(String? extension) {
    final normalized = extension?.toLowerCase();
    switch (normalized) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
      case 'oga':
        return 'audio/ogg';
      case 'opus':
        return 'audio/opus';
      default:
        return null;
    }
  }

  String _audioStatusLabel(String? mimeType) {
    if (mimeType == null || mimeType.isEmpty) {
      return 'Voice note ready';
    }
    switch (mimeType) {
      case 'audio/mpeg':
        return 'Voice note (MP3)';
      case 'audio/wav':
        return 'Voice note (WAV)';
      case 'audio/aac':
        return 'Voice note (AAC)';
      case 'audio/mp4':
        return 'Voice note (M4A)';
      case 'audio/ogg':
        return 'Voice note (OGG)';
      case 'audio/opus':
        return 'Voice note (Opus)';
      default:
        return 'Voice note attached';
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureStoreReady();
  }

  Future<void> _ensureStoreReady() async {
    if (_store.events.isEmpty ||
        _store.categories.isEmpty ||
        _store.quickPhrases.isEmpty) {
      await _store.loadData();
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final categories = List<QuizCategory>.from(_store.categories)
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final events = List<QuizEvent>.from(_store.events)
          ..sort((a, b) => a.date.compareTo(b.date));
        final wordGames = List<TranslatorWordGame>.from(_store.wordGames)
          ..sort((a, b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final quickPhrases = List<TranslatorQuickPhrase>.from(
            _store.quickPhrases)
          ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        final dictionaryEntries = List<TranslatorDictionaryEntry>.from(
            _store.translatorEntries)
          ..sort(
              (a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
        final contributorProfiles =
            List<TranslatorContributorProfile>.from(_store.contributorProfiles)
              ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
        final contributorSubmissions =
            List<TranslatorContributorSubmission>.from(
                _store.contributorSubmissions)
              ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

        return Scaffold(
          backgroundColor: _background,
          appBar: FloatingHeader(
            title: 'Learn Control Center',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Content library',
                icon: const Icon(Icons.library_books, color: Colors.white70),
                onPressed: _openContentManager,
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildOverviewRow(categories.length, events.length,
                    quickPhrases.length, dictionaryEntries.length),
                const SizedBox(height: 20),
                _buildCategoriesSection(categories),
                const SizedBox(height: 20),
                _buildEventsSection(events),
                const SizedBox(height: 20),
                _buildWordGamesSection(wordGames),
                const SizedBox(height: 20),
                _buildTranslatorSection(quickPhrases, dictionaryEntries),
                const SizedBox(height: 20),
                _buildContributorRequestsSection(contributorProfiles),
                const SizedBox(height: 20),
                _buildContributionInbox(contributorSubmissions),
                const SizedBox(height: 20),
                _buildContentCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewRow(
    int categoryCount,
    int eventCount,
    int quickPhraseCount,
    int dictionaryCount,
  ) {
    final cards = [
      _OverviewStat(
        label: 'Categories',
        value: '$categoryCount',
        icon: Icons.category_outlined,
        color: const Color(0xFFFFB300),
      ),
      _OverviewStat(
        label: 'Events',
        value: '$eventCount',
        icon: Icons.calendar_today,
        color: const Color(0xFF26C6DA),
      ),
      _OverviewStat(
        label: 'Quick phrases',
        value: '$quickPhraseCount',
        icon: Icons.bolt,
        color: const Color(0xFF00BFA5),
      ),
      _OverviewStat(
        label: 'Dictionary entries',
        value: '$dictionaryCount',
        icon: Icons.translate,
        color: const Color(0xFF7E57C2),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 22,
              child: card,
            ),
          )
          .toList(),
    );
  }

  Widget _buildCategoriesSection(List<QuizCategory> categories) {
    return _SectionCard(
      icon: Icons.category_outlined,
      title: 'Quiz categories',
      subtitle: 'Toggle visibility and keep Learn organized by topic.',
      action: TextButton.icon(
        onPressed: _showAddCategoryDialog,
        icon: const Icon(Icons.add, color: Color(0xFF00BFA5)),
        label: const Text('Add category',
            style: TextStyle(color: Color(0xFF00BFA5))),
      ),
      child: categories.isEmpty
          ? _buildEmptyState(
              'No categories yet. Add one to group quizzes by theme.')
          : Column(
              children: categories
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryTile(category),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCategoryTile(QuizCategory category) {
    final accent = category.isActive ? const Color(0xFF00BFA5) : Colors.white54;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: category.isActive
              ? accent.withAlpha((0.6 * 255).round())
              : Colors.white.withAlpha((0.08 * 255).round()),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha((0.22 * 255).round()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon,
                color: category.isActive ? Colors.white : Colors.white70),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _categoryBlurbs[category.name] ??
                      'Visible on the Learn home tab when active.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch.adaptive(
                value: category.isActive,
                activeTrackColor: const Color(0xFF00BFA5),
                onChanged: (value) async {
                  setState(() => category.isActive = value);
                  await _store.updateCategory(category);
                },
              ),
              IconButton(
                tooltip: 'Rename & icon',
                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                onPressed: () => _showEditCategoryDialog(category),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF5350), size: 20),
                onPressed: () => _confirmDeleteCategory(category),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(List<QuizEvent> events) {
    return _SectionCard(
      icon: Icons.event,
      title: 'Quiz events',
      subtitle: 'Control upcoming Learn tournaments and their questions.',
      action: TextButton.icon(
        onPressed: () => _showEventDialog(),
        icon: const Icon(Icons.add, color: Color(0xFF26C6DA)),
        label:
            const Text('New event', style: TextStyle(color: Color(0xFF26C6DA))),
      ),
      child: events.isEmpty
          ? _buildEmptyState(
              'No events created. Add one to schedule the next quiz.')
          : Column(
              children: events
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildEventCard(event),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildEventCard(QuizEvent event) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: event.color.withAlpha((0.25 * 255).round())),
        gradient: LinearGradient(
          colors: [
            event.color.withAlpha((0.18 * 255).round()),
            event.color.withAlpha((0.08 * 255).round()),
          ],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.25 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(event.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDateTime(event.date)} • ${_formatCurrency(event.prize)} prize',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: event.isActive,
                activeTrackColor: const Color(0xFF26C6DA),
                onChanged: (value) async {
                  setState(() => event.isActive = value);
                  await _store.updateEvent(event);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEventChip(Icons.people_alt_outlined,
                  '${event.participants}/${event.maxParticipants} players'),
              _buildEventChip(Icons.monetization_on_outlined,
                  'Entry ${_formatCurrency(event.entryFee)}'),
              _buildEventChip(Icons.question_answer_outlined,
                  '${event.questions.length} questions'),
              if ((event.thumbnailUrl?.trim().isNotEmpty ?? false))
                _buildEventChip(Icons.image_outlined, 'Thumbnail set'),
              if ((event.preQuizVideoUrl?.trim().isNotEmpty ?? false))
                _buildEventChip(Icons.play_circle_outline, 'Intro video'),
              ...event.categories
                  .map((category) => _buildEventChip(Icons.label, category)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _navigateToQuestions(event),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0)),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Manage questions'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showEventDialog(existing: event),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                      color: Colors.white.withAlpha((0.25 * 255).round())),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit event'),
              ),
              TextButton.icon(
                onPressed: () => _confirmDeleteEvent(event),
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
                label: const Text('Delete',
                    style: TextStyle(color: Color(0xFFEF5350))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWordGamesSection(List<TranslatorWordGame> games) {
    return _SectionCard(
      icon: Icons.videogame_asset_outlined,
      title: 'Word games',
      subtitle:
          'Design Wordscapes-style puzzles and word quests for learners.',
      action: TextButton.icon(
        onPressed: () => _showWordGameDialog(),
        icon: const Icon(Icons.add, color: Color(0xFF26C6DA)),
        label: const Text('New game',
            style: TextStyle(color: Color(0xFF26C6DA))),
      ),
      child: games.isEmpty
          ? _buildEmptyState(
              'No word games created yet. Add one to unlock the Learn games tab.',
            )
          : Column(
              children: games
                  .map(
                    (game) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildWordGameCard(game),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildWordGameCard(TranslatorWordGame game) {
    final prompts = List<TranslatorWordGamePrompt>.from(game.prompts)
      ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    final accent = game.isActive
        ? const Color(0xFF26C6DA)
        : Colors.white.withAlpha((0.18 * 255).round());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha((0.45 * 255).round())),
        color: Colors.white.withAlpha((0.05 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.description.isEmpty
                          ? 'Tap edit to add a short description for learners.'
                          : game.description,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch.adaptive(
                    value: game.isActive,
                    activeTrackColor: const Color(0xFF26C6DA),
                    onChanged: (value) async {
                      setState(() => game.isActive = value);
                      await _store.updateWordGameDetails(
                        gameId: game.id,
                        isActive: value,
                      );
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit details',
                        icon: const Icon(Icons.edit,
                            color: Colors.white70, size: 20),
                        onPressed: () => _showWordGameDialog(existing: game),
                      ),
                      IconButton(
                        tooltip: 'Delete game',
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFEF5350), size: 20),
                        onPressed: () => _confirmDeleteWordGame(game),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildWordGameInfoPill(
                  Icons.extension, _wordGameStyleLabel(game.gameStyle)),
              _buildWordGameInfoPill(
                  Icons.text_fields, '${prompts.length} prompts'),
              _buildWordGameInfoPill(
                  Icons.emoji_events,
                  'Best ${game.bestScore}/${game.bestOutOf == 0 ? prompts.length : game.bestOutOf}'),
              if (game.playCount > 0)
                _buildWordGameInfoPill(
                    Icons.play_arrow_rounded, '${game.playCount} plays'),
            ],
          ),
          if (prompts.isEmpty) ...[
            const SizedBox(height: 12),
            _buildEmptyState(
                'No prompts yet. Add at least one to unlock the Play button.'),
          ] else ...[
            const SizedBox(height: 12),
            Column(
              children: prompts
                  .map(
                    (prompt) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildWordGamePromptTile(game, prompt),
                    ),
                  )
                  .toList(),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showPromptEditor(game: game),
              icon: const Icon(Icons.add, color: Color(0xFF26C6DA)),
              label: const Text('Add prompt',
                  style: TextStyle(color: Color(0xFF26C6DA))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordGameInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWordGamePromptTile(
    TranslatorWordGame game,
    TranslatorWordGamePrompt prompt,
  ) {
    final hasScreenshot =
        prompt.screenshotImageUrl != null && prompt.screenshotImageUrl!.trim().isNotEmpty;
    final translation = prompt.translation.trim();
    final hint = prompt.hint?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasScreenshot
              ? const Color(0xFF26C6DA).withAlpha((0.45 * 255).round())
              : Colors.white.withAlpha((0.12 * 255).round()),
        ),
        color: Colors.white.withAlpha((0.04 * 255).round()),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.term.isEmpty ? 'Untitled prompt' : prompt.term,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _promptClueLabel(prompt),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                if (translation.isNotEmpty && prompt.type != 'translation') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Clue: $translation',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hint: $hint',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                if (hasScreenshot) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.image_outlined,
                          size: 16, color: Color(0xFF26C6DA)),
                      SizedBox(width: 6),
                      Text(
                        'Screenshot attached',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Preview screenshot',
                icon: const Icon(Icons.slideshow,
                    color: Colors.white70, size: 20),
                onPressed:
                    hasScreenshot ? () => _previewPromptScreenshot(prompt) : null,
              ),
              IconButton(
                tooltip: 'Edit prompt',
                icon:
                    const Icon(Icons.edit, color: Colors.white70, size: 20),
                onPressed: () =>
                    _showPromptEditor(game: game, existing: prompt),
              ),
              IconButton(
                tooltip: 'Delete prompt',
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF5350), size: 20),
                onPressed: () =>
                    _confirmDeletePrompt(game, prompt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _promptClueLabel(TranslatorWordGamePrompt prompt) {
    final style = prompt.type.trim().toLowerCase();
    switch (style) {
      case 'translation':
        return 'Translate: ${prompt.term.isEmpty ? prompt.translation : prompt.term}';
      case 'sentence':
        return 'Complete the sentence';
      case 'scramble':
      case 'word_trip':
      case 'word_builder':
      default:
        return 'Solve: ${prompt.term.isEmpty ? 'Update prompt' : prompt.term}';
    }
  }

  String _wordGameStyleLabel(String style) {
    final normalized = style.trim().toLowerCase();
    switch (normalized) {
      case 'wordle':
      case 'word-quest':
        return 'Word quest';
      case 'word_trip':
        return 'Trail builder';
      case 'word_builder':
        return 'Tile builder';
      case 'scramble':
      default:
        return 'Scramble';
    }
  }

  Future<void> _showWordGameDialog({TranslatorWordGame? existing}) async {
    final titleController =
        TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    String selectedStyle = existing?.gameStyle ?? 'scramble';
    bool isActive = existing?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            existing == null ? 'Create word game' : 'Edit word game',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Game title *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Short blurb shown on the Learn games tab',
                    hintStyle: TextStyle(color: Colors.white38),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStyle,
                  dropdownColor: const Color(0xFF0A1628),
                  decoration: const InputDecoration(
                    labelText: 'Game style *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'scramble',
                      child: Text('Scramble builder'),
                    ),
                    DropdownMenuItem(
                      value: 'word_trip',
                      child: Text('Trail builder'),
                    ),
                    DropdownMenuItem(
                      value: 'wordle',
                      child: Text('Word quest'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStyle = value);
                  },
                ),
                const SizedBox(height: 12),
        SwitchListTile.adaptive(
                  value: isActive,
                  onChanged: (value) =>
                      setDialogState(() => isActive = value),
                  title: const Text('Active',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  subtitle: const Text(
                    'Inactive games stay hidden from learners until you toggle them on.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  activeTrackColor: const Color(0xFF26C6DA),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();

                if (title.isEmpty) {
                  _showSnack('Enter a game title.');
                  return;
                }

                if (existing == null) {
                  final game = TranslatorWordGame(
                    id: 'game-${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    description: description,
                    gameStyle: selectedStyle,
                    isActive: isActive,
                  );
                  await _store.addWordGame(game);
                } else {
                  await _store.updateWordGameDetails(
                    gameId: existing.id,
                    title: title,
                    description: description,
                    gameStyle: selectedStyle,
                    isActive: isActive,
                  );
                }

                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA)),
              child: Text(existing == null ? 'Create' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _confirmDeleteWordGame(TranslatorWordGame game) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete word game?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${game.title}" and all its prompts? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.deleteWordGame(game.id);
    }
  }

  Future<void> _showPromptEditor({
    required TranslatorWordGame game,
    TranslatorWordGamePrompt? existing,
  }) async {
    final termController =
        TextEditingController(text: existing?.term ?? '');
    final translationController =
        TextEditingController(text: existing?.translation ?? '');
    final hintController =
        TextEditingController(text: existing?.hint ?? '');
    final sentenceController =
        TextEditingController(text: existing?.sentenceTemplate ?? '');
    final alternateController = TextEditingController(
      text: existing == null
          ? ''
          : existing.alternateAnswers.join(', '),
    );
    final screenshotController = TextEditingController(
      text: existing?.screenshotImageUrl ?? '',
    );

    String promptType = existing?.type ?? 'scramble';
    String? selectedScreenshotPath =
        screenshotController.text.trim().isEmpty
            ? null
            : screenshotController.text.trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget? screenshotPreview;
          if (selectedScreenshotPath != null) {
            screenshotPreview = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                child: _buildScreenshotPreview(selectedScreenshotPath!),
              ),
            );
          }

          String friendlyName(String value) {
            final parts = value.split(RegExp(r'[\\/]'));
            return parts.isEmpty ? value : parts.last;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              existing == null ? 'Add prompt' : 'Edit prompt',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: promptType,
                    dropdownColor: const Color(0xFF0A1628),
                    decoration: const InputDecoration(
                      labelText: 'Prompt type',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    iconEnabledColor: Colors.white70,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 'scramble',
                        child: Text('Scramble'),
                      ),
                      DropdownMenuItem(
                        value: 'word_trip',
                        child: Text('Trail builder'),
                      ),
                      DropdownMenuItem(
                        value: 'wordle',
                        child: Text('Word quest'),
                      ),
                      DropdownMenuItem(
                        value: 'translation',
                        child: Text('Translation check'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => promptType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Target word *',
                      hintText: 'The solution learners must find',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: translationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Clue or translation',
                      hintText: 'Optional clue displayed in the sheet',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hintController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Hint (optional)',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sentenceController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Sentence template (optional)',
                      hintText: 'For fill-in-the-blank sentence prompts',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: alternateController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alternate answers',
                      hintText: 'Separate options with commas',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: screenshotController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => setDialogState(() {
                      final trimmed = value.trim();
                      selectedScreenshotPath =
                          trimmed.isEmpty ? null : trimmed;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Screenshot image (optional)',
                      hintText: 'Paste an https:// URL or an assets/ path',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              allowMultiple: false,
                            );
                            if (result == null || result.files.isEmpty) {
                              return;
                            }
                            final file = result.files.single;
                            final path = file.path;
                            if (path == null) {
                              _showSnack('Unable to read the selected image.');
                              return;
                            }
                            setDialogState(() {
                              selectedScreenshotPath = path;
                              screenshotController.text = path;
                            });
                          } catch (_) {
                            _showSnack('Failed to pick an image.');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF26C6DA)),
                          foregroundColor: const Color(0xFF26C6DA),
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose from gallery'),
                      ),
                      if (selectedScreenshotPath != null)
                        Text(
                          friendlyName(selectedScreenshotPath!),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                      if (selectedScreenshotPath != null)
                        IconButton(
                          tooltip: 'Remove screenshot',
                          icon:
                              const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () => setDialogState(() {
                            selectedScreenshotPath = null;
                            screenshotController.clear();
                          }),
                        ),
                    ],
                  ),
                  if (screenshotPreview != null) ...[
                    const SizedBox(height: 12),
                    screenshotPreview,
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final term = termController.text.trim();
                  if (term.isEmpty) {
                    _showSnack('Enter the solution word.');
                    return;
                  }

                  final translation = translationController.text.trim();
                  final hint = hintController.text.trim();
                  final sentence = sentenceController.text.trim();
                  final alternateRaw = alternateController.text.trim();
                  final screenshot = screenshotController.text.trim();
                  final alternates = alternateRaw.isEmpty
                      ? <String>[]
                      : alternateRaw
                          .split(RegExp(r'[\n,]'))
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList();

                  final prompt = TranslatorWordGamePrompt(
                    id: existing?.id ??
                        'prompt-${DateTime.now().millisecondsSinceEpoch}',
                    type: promptType,
                    term: term,
                    translation: translation,
                    hint: hint.isEmpty ? null : hint,
                    sentenceTemplate:
                        sentence.isEmpty ? null : sentence,
                    screenshotImageUrl:
                        screenshot.isEmpty ? null : screenshot,
                    alternateAnswers: alternates,
                    createdAt: existing?.createdAt,
                    updatedAt: existing?.updatedAt,
                  );

                  if (existing == null) {
                    await _store.addPromptToGame(
                      gameId: game.id,
                      prompt: prompt,
                    );
                  } else {
                    await _store.updatePromptInGame(
                      gameId: game.id,
                      prompt: prompt,
                    );
                  }

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA)),
                child: Text(existing == null ? 'Add prompt' : 'Save changes'),
              ),
            ],
          );
        },
      ),
    );

    termController.dispose();
    translationController.dispose();
    hintController.dispose();
    sentenceController.dispose();
    alternateController.dispose();
    screenshotController.dispose();
  }

  Future<void> _confirmDeletePrompt(
    TranslatorWordGame game,
    TranslatorWordGamePrompt prompt,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete prompt?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${prompt.term}" from ${game.title}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.removePromptFromGame(
        gameId: game.id,
        promptId: prompt.id,
      );
    }
  }

  Future<void> _previewPromptScreenshot(
      TranslatorWordGamePrompt prompt) async {
    final source = prompt.screenshotImageUrl;
    if (source == null || source.trim().isEmpty) {
      _showSnack('No screenshot attached to this prompt.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 360,
            child: _buildScreenshotPreview(source),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotPreview(String source) {
    final trimmed = source.trim();
    if (_isNetworkPath(trimmed)) {
      return Image.network(trimmed, fit: BoxFit.cover);
    }
    if (_isAssetPath(trimmed)) {
      return Image.asset(trimmed, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.white12,
                alignment: Alignment.center,
                child: const Text(
                  'Asset not found',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ));
    }
    try {
      final file = io.File(trimmed);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    } catch (_) {
      // Ignore file system errors and fall through to placeholder.
    }
    return Container(
      height: 200,
      color: Colors.white12,
      alignment: Alignment.center,
      child: const Text(
        'Unable to load screenshot',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  bool _isNetworkPath(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  bool _isAssetPath(String value) => value.startsWith('assets/');

  Widget _buildTranslatorSection(
    List<TranslatorQuickPhrase> quickPhrases,
    List<TranslatorDictionaryEntry> entries,
  ) {
    final kibembeEntries = _store.entriesForLanguage('Kibembe')
      ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

    return _SectionCard(
      icon: Icons.translate_rounded,
      title: 'Quick phrases & dictionary',
      subtitle: 'Everything that powers the Translate tab stays in sync here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick phrases',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showQuickPhraseDialog(),
                icon: const Icon(Icons.add, color: Color(0xFF00BFA5)),
                label: const Text('Add phrase',
                    style: TextStyle(color: Color(0xFF00BFA5))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (quickPhrases.isEmpty)
            _buildEmptyState(
                'No quick phrases yet. Add callouts for hosts to tap instantly.')
          else
            Column(
              children: quickPhrases
                  .map(
                    (phrase) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildQuickPhraseTile(phrase),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withAlpha((0.08 * 255).round())),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dictionary entries',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showDictionaryEntryDialog(),
                icon: const Icon(Icons.add, color: Color(0xFF26C6DA)),
                label: const Text('Add word',
                    style: TextStyle(color: Color(0xFF26C6DA))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _buildEmptyState(
                'No dictionary entries yet. Save both sides to unlock translations.')
          else
            Column(
              children: kibembeEntries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDictionaryEntryTile(entry),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickPhraseTile(TranslatorQuickPhrase phrase) {
    final kibembe = phrase.translations['Kibembe'] ?? '—';
    final english = phrase.translations['English'] ?? '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text('Kibembe: $kibembe',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('English: $english',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                if (phrase.audioBase64 != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.volume_up,
                          color: Color(0xFF00BFA5), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _audioStatusLabel(phrase.audioMimeType),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit, color: Color(0xFF00BFA5)),
                onPressed: () => _showQuickPhraseDialog(existing: phrase),
              ),
              IconButton(
                tooltip: 'Delete',
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
                onPressed: () => _confirmDeleteQuickPhrase(phrase),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryEntryTile(TranslatorDictionaryEntry entry) {
    final english = entry.sourceLanguage == 'English'
        ? entry.term
        : entry.translations['English'] ?? '—';
    final kibembe = entry.sourceLanguage == 'Kibembe'
        ? entry.term
        : entry.translations['Kibembe'] ?? '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF26C6DA), size: 18),
              const SizedBox(width: 8),
              Text(
                '${entry.sourceLanguage} → ${entry.translations.keys.join(', ')}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit entry',
                icon: const Icon(Icons.edit, color: Color(0xFF26C6DA)),
                onPressed: () => _showDictionaryEntryDialog(existing: entry),
              ),
              IconButton(
                tooltip: 'Delete entry',
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
                onPressed: () => _confirmDeleteDictionaryEntry(entry),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('English: $english',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Kibembe: $kibembe',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (entry.partOfSpeech != null &&
              entry.partOfSpeech!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Part of speech: ${entry.partOfSpeech}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          if (entry.example != null && entry.example!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Example: ${entry.example}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (entry.audioBase64 != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_up, color: Color(0xFF26C6DA), size: 16),
                const SizedBox(width: 6),
                Text(
                  _audioStatusLabel(entry.audioMimeType),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContributorRequestsSection(
      List<TranslatorContributorProfile> profiles) {
    final pending = profiles.where((profile) => profile.isPending).toList();
    final approved =
        profiles.where((profile) => profile.isApproved).take(5).toList();
    final rejected = profiles
        .where((profile) => !profile.isPending && !profile.isApproved)
        .take(5)
        .toList();

    return _SectionCard(
      icon: Icons.volunteer_activism,
      title: 'Contributor access requests',
      subtitle:
          'Approve trusted learners so they can submit new words and voice notes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isEmpty)
            _buildEmptyState('No pending contributor requests right now.')
          else
            Column(
              children: pending
                  .map((profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildContributorRequestTile(profile),
                      ))
                  .toList(),
            ),
          if (approved.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recently approved',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...approved.map(
              (profile) => _buildContributorSummary(profile, Colors.teal),
            ),
          ],
          if (rejected.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Declined this week',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...rejected.map(
              (profile) => _buildContributorSummary(profile, Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContributorRequestTile(TranslatorContributorProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  profile.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatQuizEventDate(profile.requestedAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          if (profile.applicationNote != null &&
              profile.applicationNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              profile.applicationNote!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveContributor(profile),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectContributor(profile),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: const BorderSide(color: Color(0xFFEF5350)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributorSummary(
      TranslatorContributorProfile profile, Color color) {
    final statusLabel = profile.isApproved ? 'Approved' : 'Rejected';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withAlpha((0.05 * 255).round()),
          border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if (profile.reviewedAt != null)
                    Text(
                      formatQuizEventDate(profile.reviewedAt!),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(60),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionInbox(
      List<TranslatorContributorSubmission> submissions) {
    final pending = submissions
        .where((submission) => submission.isPending)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final approved = submissions
        .where((submission) => submission.status == 'approved')
        .toList()
      ..sort((a, b) =>
          (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));
    final recentApproved = approved.take(6).toList();
    final rejected = submissions
        .where((submission) => submission.status == 'rejected')
        .toList()
      ..sort((a, b) =>
          (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));

    return _SectionCard(
      icon: Icons.inbox_outlined,
      title: 'User submissions',
      subtitle:
          'Review suggested translations and publish them to the library.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isEmpty)
            _buildEmptyState('No pending submissions right now.')
          else
            Column(
              children: pending
                  .map((submission) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildContributionTile(submission),
                      ))
                  .toList(),
            ),
          if (recentApproved.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recent approvals',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...recentApproved.map(_buildContributionSummary),
          ],
          if (approved.isNotEmpty || rejected.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _showSubmissionHistorySheet(submissions.toList()),
                icon: const Icon(Icons.history, color: Color(0xFF26C6DA)),
                label: const Text('View history',
                    style: TextStyle(color: Color(0xFF26C6DA))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContributionTile(TranslatorContributorSubmission submission) {
    final translationPreview = submission.translations.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_add, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.term,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'From ${submission.sourceLanguage} by ${submission.contributorName}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                formatQuizEventDate(submission.submittedAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(
            translationPreview,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (submission.partOfSpeech != null &&
              submission.partOfSpeech!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Part of speech: ${submission.partOfSpeech}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
          if (submission.example != null && submission.example!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Example: ${submission.example}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          if (submission.audioBase64 != null &&
              submission.audioBase64!.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _previewContributionAudio(submission),
              icon: const Icon(Icons.volume_up, color: Color(0xFFFFB300)),
              label: const Text('Play voice note'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFB300),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveContribution(submission),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve & publish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectContribution(submission),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: const BorderSide(color: Color(0xFFEF5350)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContributionSummary(
      TranslatorContributorSubmission submission) {
    final approved = submission.status == 'approved';
    final color = approved ? const Color(0xFF00BFA5) : const Color(0xFFEF5350);
    final statusText = approved ? 'Approved' : 'Rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(submission.term,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${submission.contributorName} • ${formatQuizEventDate(submission.submittedAt)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(statusText,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveContributor(
      TranslatorContributorProfile profile) async {
    await _store.updateContributorStatus(
      profileId: profile.id,
      status: 'approved',
      reviewer: 'Admin',
    );
    _showSnack('Approved ${profile.displayName}.');
  }

  Future<void> _rejectContributor(
      TranslatorContributorProfile profile) async {
    final noteController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject request',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteController.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.black),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    noteController.dispose();

    if (reason == null) {
      return;
    }

    await _store.updateContributorStatus(
      profileId: profile.id,
      status: 'rejected',
      reviewer: 'Admin',
      note: reason.isEmpty ? null : reason,
    );
    _showSnack('Declined ${profile.displayName}.');
  }

  Future<void> _approveContribution(
      TranslatorContributorSubmission submission) async {
    await _store.decideOnContributorSubmission(
      submissionId: submission.id,
      status: 'approved',
      reviewer: 'Admin',
    );
    _showSnack('Published ${submission.term} to the translator.');
  }

  Future<void> _rejectContribution(
      TranslatorContributorSubmission submission) async {
    final noteController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject submission',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteController.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.black),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    noteController.dispose();

    if (reason == null) {
      return;
    }

    await _store.decideOnContributorSubmission(
      submissionId: submission.id,
      status: 'rejected',
      reviewer: 'Admin',
      note: reason.isEmpty ? null : reason,
    );
    _showSnack('Rejected ${submission.term}.');
  }

  Future<void> _previewContributionAudio(
      TranslatorContributorSubmission submission) async {
    final audioData = submission.audioBase64;
    if (audioData == null || audioData.isEmpty) {
      _showSnack('No voice note attached.');
      return;
    }
    final audioPlayer = AudioPlayer();
    try {
      final bytes = base64Decode(audioData);
      await audioPlayer.play(BytesSource(bytes));
      await audioPlayer.onPlayerComplete.first;
    } catch (_) {
      _showSnack('Unable to play the voice note.');
    } finally {
      await audioPlayer.stop();
      await audioPlayer.dispose();
    }
  }

  void _showSubmissionHistorySheet(
      List<TranslatorContributorSubmission> submissions) {
    if (submissions.isEmpty) {
      return;
    }
    final pending = submissions
        .where((submission) => submission.isPending)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final approved = submissions
        .where((submission) => submission.status == 'approved')
        .toList()
      ..sort((a, b) =>
          (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));
    final rejected = submissions
        .where((submission) => submission.status == 'rejected')
        .toList()
      ..sort((a, b) =>
          (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Submission history',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (pending.isNotEmpty) ...[
                          Text('Pending review',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ...pending.map(_buildHistoryTile),
                          const SizedBox(height: 24),
                        ],
                        if (approved.isNotEmpty) ...[
                          Text('Approved',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ...approved.map(_buildHistoryTile),
                          const SizedBox(height: 24),
                        ],
                        if (rejected.isNotEmpty) ...[
                          Text('Rejected',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ...rejected.map(_buildHistoryTile),
                        ],
                        if (pending.isEmpty &&
                            approved.isEmpty &&
                            rejected.isEmpty)
                          const Text(
                            'No submissions logged yet.',
                            style: TextStyle(color: Colors.white60),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTile(TranslatorContributorSubmission submission) {
    final status = submission.status;
    late final Color accent;
    late final String statusLabel;
    switch (status) {
      case 'approved':
        accent = const Color(0xFF00BFA5);
        statusLabel = 'Approved';
        break;
      case 'rejected':
        accent = const Color(0xFFEF5350);
        statusLabel = 'Rejected';
        break;
      default:
        accent = const Color(0xFFFFB300);
        statusLabel = 'Pending';
    }

    final translationPreview = submission.translations.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
    final decisionDate = submission.decidedAt ?? submission.submittedAt;

    final backgroundAlpha = status == 'rejected' ? 0.28 : 0.18;
    final borderAlpha = status == 'rejected' ? 0.6 : 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withAlpha((backgroundAlpha * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha((borderAlpha * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.term,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${submission.contributorName}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha((0.35 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            translationPreview,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted ${formatQuizEventDate(submission.submittedAt)} • '
            '${status == 'pending' ? 'Awaiting review' : 'Decided ${formatQuizEventDate(decisionDate)}'}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          if (submission.partOfSpeech != null &&
              submission.partOfSpeech!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Part of speech: ${submission.partOfSpeech}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
          if (submission.example != null && submission.example!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Example: ${submission.example}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          if (submission.reviewNote != null &&
              submission.reviewNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${submission.reviewNote}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
        color: Colors.white.withAlpha((0.04 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Curate Learn articles',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review pending submissions, approve highlights, and craft premium content.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _openContentManager,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5)),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open content manager'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withAlpha((0.04 * 255).round()),
      ),
      child: Text(message,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    IconData selectedIcon = _categoryIcons.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create category',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category name *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pick an icon',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categoryIcons
                      .map(
                        (icon) => InkWell(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selectedIcon == icon
                                  ? const Color(0xFF00BFA5)
                                      .withAlpha((0.2 * 255).round())
                                  : Colors.white
                                      .withAlpha((0.08 * 255).round()),
                              border: Border.all(
                                color: selectedIcon == icon
                                    ? const Color(0xFF00BFA5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(icon, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showSnack('Give the category a name first.');
                  return;
                }

                final category = QuizCategory(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  icon: selectedIcon,
                );
                final navigator = Navigator.of(dialogContext);
                await _store.addCategory(category);
                if (navigator.mounted) navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCategoryDialog(QuizCategory category) async {
    final nameController = TextEditingController(text: category.name);
    IconData selectedIcon = category.icon;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit category',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category name *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Pick an icon',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categoryIcons
                      .map(
                        (icon) => InkWell(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selectedIcon == icon
                                  ? const Color(0xFF00BFA5)
                                      .withAlpha((0.2 * 255).round())
                                  : Colors.white
                                      .withAlpha((0.08 * 255).round()),
                              border: Border.all(
                                color: selectedIcon == icon
                                    ? const Color(0xFF00BFA5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(icon, color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showSnack('Name cannot be empty.');
                  return;
                }

                category.name = name;
                category.icon = selectedIcon;
                final navigator = Navigator.of(dialogContext);
                await _store.updateCategory(category);
                if (navigator.mounted) navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5)),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(QuizCategory category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete category?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${category.name}"? Any quizzes will stay but lose this tag.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.deleteCategory(category.id);
    }
  }

  Future<void> _showEventDialog({QuizEvent? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subtitleController =
        TextEditingController(text: existing?.subtitle ?? '');
    final prizeController = TextEditingController(
      text: existing != null ? existing.prize.toStringAsFixed(0) : '0',
    );
    final entryFeeController = TextEditingController(
      text: existing != null ? existing.entryFee.toStringAsFixed(0) : '0',
    );
    final participantController = TextEditingController(
      text: existing != null ? existing.maxParticipants.toString() : '1000',
    );
    final thumbnailController =
        TextEditingController(text: existing?.thumbnailUrl ?? '');
    final preVideoController =
        TextEditingController(text: existing?.preQuizVideoUrl ?? '');
  final preVideoTitleController =
    TextEditingController(text: existing?.preQuizVideoTitle ?? '');

    String? selectedThumbnailPath = thumbnailController.text.trim().isEmpty
        ? null
        : thumbnailController.text.trim();
    String? selectedVideoPath = preVideoController.text.trim().isEmpty
        ? null
        : preVideoController.text.trim();

    DateTime selectedDate =
        existing?.date ?? DateTime.now().add(const Duration(hours: 1));
    IconData selectedIcon = existing?.icon ?? Icons.quiz_outlined;
    Color selectedColor = existing?.color ?? _eventSwatches.first;
    final Set<String> selectedCategories = {...existing?.categories ?? []};

    final categories = List<QuizCategory>.from(_store.categories);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          String friendlyName(String value) {
            if (value.isEmpty) {
              return '';
            }
            final segments = value.split(RegExp(r'[\\/]'));
            return segments.isEmpty ? value : segments.last;
          }

          bool isYouTubeLink(String value) {
            final lower = value.toLowerCase();
            return lower.contains('youtube.com') || lower.contains('youtu.be');
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null ? 'Create event' : 'Edit event',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Subtitle *',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prizeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Prize (₦₲)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: entryFeeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Entry fee (₦₲)',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: participantController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Max participants',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start time',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final newDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (newDate == null) return;
                            if (!context.mounted) return;
                            final newTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDate),
                            );
                            if (newTime == null) return;
                            setDialogState(() {
                              selectedDate = DateTime(
                                newDate.year,
                                newDate.month,
                                newDate.day,
                                newTime.hour,
                                newTime.minute,
                              );
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white
                                    .withAlpha((0.3 * 255).round())),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(_formatDateTime(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Categories',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => FilterChip(
                            label: Text(category.name),
                            selected:
                                selectedCategories.contains(category.name),
                            onSelected: (value) {
                              setDialogState(() {
                                if (value) {
                                  selectedCategories.add(category.name);
                                } else {
                                  selectedCategories.remove(category.name);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Icon & accent color',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          Icons.quiz,
                          Icons.sports_soccer,
                          Icons.public,
                          Icons.account_balance,
                          Icons.psychology,
                          Icons.rocket_launch,
                        ]
                            .map(
                              (icon) => InkWell(
                                onTap: () =>
                                    setDialogState(() => selectedIcon = icon),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: selectedIcon == icon
                                        ? Colors.white
                                            .withAlpha((0.18 * 255).round())
                                        : Colors.white
                                            .withAlpha((0.06 * 255).round()),
                                    border: Border.all(
                                      color: selectedIcon == icon
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Icon(icon, color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _eventSwatches
                            .map(
                              (color) => GestureDetector(
                                onTap: () =>
                                    setDialogState(() => selectedColor = color),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selectedColor == color
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: thumbnailController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => setDialogState(() {
                      final trimmed = value.trim();
                      selectedThumbnailPath = trimmed.isEmpty ? null : trimmed;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Thumbnail image (optional)',
                      hintText:
                          'assets/images/quiz.png, gallery file path, or https://...',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              allowMultiple: false,
                            );
                            if (result == null || result.files.isEmpty) {
                              return;
                            }
                            final file = result.files.single;
                            final path = file.path;
                            if (path == null) {
                              _showSnack('Unable to read the selected image.');
                              return;
                            }
                            setDialogState(() {
                              selectedThumbnailPath = path;
                              thumbnailController.text = path;
                            });
                          } catch (_) {
                            _showSnack('Failed to pick an image.');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF26C6DA),
                          side: const BorderSide(color: Color(0xFF26C6DA)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose from gallery'),
                      ),
                      if (selectedThumbnailPath != null)
                        Text(
                          friendlyName(selectedThumbnailPath!),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      if (selectedThumbnailPath != null)
                        IconButton(
                          tooltip: 'Remove thumbnail',
                          onPressed: () => setDialogState(() {
                            selectedThumbnailPath = null;
                            thumbnailController.clear();
                          }),
                          icon: const Icon(Icons.clear, color: Colors.white54),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: preVideoTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Intro clip header (optional)',
                      hintText: 'Displayed at the top of the warm-up screen',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: preVideoController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) => setDialogState(() {
                      final trimmed = value.trim();
                      selectedVideoPath = trimmed.isEmpty ? null : trimmed;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Intro video (optional)',
                      hintText:
                          'Paste a YouTube link, upload from gallery, or reference an asset.',
                      hintStyle: TextStyle(color: Colors.white38),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.video,
                              allowMultiple: false,
                            );
                            if (result == null || result.files.isEmpty) {
                              return;
                            }
                            final file = result.files.single;
                            final path = file.path;
                            if (path == null) {
                              _showSnack('Unable to read the selected video.');
                              return;
                            }
                            setDialogState(() {
                              selectedVideoPath = path;
                              preVideoController.text = path;
                            });
                          } catch (_) {
                            _showSnack('Failed to pick a video.');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF26C6DA),
                          side: const BorderSide(color: Color(0xFF26C6DA)),
                        ),
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Choose intro clip'),
                      ),
                      if (selectedVideoPath != null)
                        Text(
                          friendlyName(selectedVideoPath!),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      if (selectedVideoPath != null)
                        IconButton(
                          tooltip: 'Remove intro video',
                          onPressed: () => setDialogState(() {
                            selectedVideoPath = null;
                            preVideoController.clear();
                          }),
                          icon: const Icon(Icons.clear, color: Colors.white54),
                        ),
                    ],
                  ),
                  if (selectedVideoPath != null &&
                      isYouTubeLink(selectedVideoPath!))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Detected YouTube link. Learners must finish the clip before the quiz starts.',
                        style: TextStyle(
                            color: Colors.white.withAlpha(170), fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final subtitle = subtitleController.text.trim();
                  final prize = double.tryParse(prizeController.text.trim());
                  final entryFee =
                      double.tryParse(entryFeeController.text.trim());
                  final maxParticipants =
                      int.tryParse(participantController.text.trim());

                  if (title.isEmpty || subtitle.isEmpty) {
                    _showSnack('Title and subtitle are required.');
                    return;
                  }
                  if (prize == null || entryFee == null) {
                    _showSnack('Provide prize and entry fee in numbers.');
                    return;
                  }
                  if (selectedCategories.isEmpty) {
                    _showSnack('Pick at least one category.');
                    return;
                  }

                  final thumbnailPath = thumbnailController.text.trim();
                  final videoPath = preVideoController.text.trim();
                  final videoHeader = preVideoTitleController.text.trim();

                  final event = QuizEvent(
                    id: existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    subtitle: subtitle,
                    date: selectedDate,
                    participants: existing?.participants ?? 0,
                    maxParticipants:
                        maxParticipants ?? existing?.maxParticipants ?? 1000,
                    prize: prize,
                    entryFee: entryFee,
                    icon: selectedIcon,
                    color: selectedColor,
                    categories: selectedCategories.toList(),
                    joined: existing?.joined ?? false,
                    isActive: existing?.isActive ?? true,
                    questions: List<QuizQuestion>.from(
                        existing?.questions ?? const <QuizQuestion>[]),
                    thumbnailUrl: thumbnailPath.isEmpty ? null : thumbnailPath,
                    preQuizVideoUrl: videoPath.isEmpty ? null : videoPath,
            preQuizVideoTitle:
              videoHeader.isEmpty ? null : videoHeader,
                  );

                  if (existing == null) {
                    await _store.addEvent(event);
                  } else {
                    await _store.updateEvent(event);
                  }

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA)),
                child: Text(existing == null ? 'Create event' : 'Save changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteEvent(QuizEvent event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Delete event?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${event.title}" from the Learn schedule?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.deleteEvent(event.id);
    }
  }

  Future<void> _showQuickPhraseDialog({TranslatorQuickPhrase? existing}) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final kibembeController =
        TextEditingController(text: existing?.translations['Kibembe'] ?? '');
    final englishController =
        TextEditingController(text: existing?.translations['English'] ?? '');
    String? audioBase64 = existing?.audioBase64;
    String? audioMimeType = existing?.audioMimeType;

    final recorder = AudioRecorder();
    final audioPlayer = AudioPlayer();
    bool dialogMounted = true;
    bool isRecording = false;
    bool isPreviewPlaying = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> stopRecordingIfActive() async {
            if (!await recorder.isRecording()) {
              return;
            }
            final path = await recorder.stop();
            if (path == null) {
              setDialogState(() => isRecording = false);
              return;
            }
            try {
              final file = io.File(path);
              final bytes = await file.readAsBytes();
              try {
                await file.delete();
              } catch (_) {}
              setDialogState(() {
                audioBase64 = base64Encode(bytes);
                audioMimeType = 'audio/aac';
                isRecording = false;
              });
            } catch (error) {
              _showSnack('Unable to save recording.');
              setDialogState(() => isRecording = false);
            }
          }

          Future<void> toggleRecording() async {
            if (isRecording) {
              await stopRecordingIfActive();
              return;
            }
            if (kIsWeb) {
              _showSnack('Recording is not supported in the browser.');
              return;
            }
            if (!await recorder.hasPermission()) {
              _showSnack('Microphone permission denied.');
              return;
            }
            try {
              final tempPath =
                  '${io.Directory.systemTemp.path}${io.Platform.pathSeparator}learn_quick_phrase_${DateTime.now().millisecondsSinceEpoch}.m4a';
              await recorder.start(
                const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: 128000,
                  sampleRate: 44100,
                ),
                path: tempPath,
              );
              setDialogState(() {
                isRecording = true;
                audioBase64 = null;
                audioMimeType = null;
                isPreviewPlaying = false;
              });
            } catch (_) {
              _showSnack('Failed to start recording.');
            }
          }

          Future<void> pickAudioFile() async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.audio,
                allowMultiple: false,
                withData: true,
              );
              if (result == null || result.files.isEmpty) {
                return;
              }
              final file = result.files.single;
              final bytes = file.bytes ??
                  (file.path != null
                      ? await io.File(file.path!).readAsBytes()
                      : null);
              if (bytes == null) {
                _showSnack('Could not read the selected file.');
                return;
              }
              await audioPlayer.stop();
              setDialogState(() {
                audioBase64 = base64Encode(bytes);
                audioMimeType = _inferMimeType(file.extension) ?? 'audio/mpeg';
                isPreviewPlaying = false;
                isRecording = false;
              });
            } catch (_) {
              _showSnack('Failed to import audio file.');
            }
          }

          Future<void> playPreview() async {
            if (audioBase64 == null || isPreviewPlaying) {
              return;
            }
            try {
              await audioPlayer.stop();
              final bytes = base64Decode(audioBase64!);
              await audioPlayer.play(BytesSource(bytes));
              setDialogState(() => isPreviewPlaying = true);
              audioPlayer.onPlayerComplete.first.then((_) {
                if (!dialogMounted) return;
                setDialogState(() => isPreviewPlaying = false);
              });
            } catch (_) {
              _showSnack('Unable to play the voice note.');
              setDialogState(() => isPreviewPlaying = false);
            }
          }

          Future<void> stopPreview() async {
            await audioPlayer.stop();
            setDialogState(() => isPreviewPlaying = false);
          }

          Future<void> removeAudio() async {
            await audioPlayer.stop();
            setDialogState(() {
              audioBase64 = null;
              audioMimeType = null;
              isPreviewPlaying = false;
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
                existing == null ? 'Add quick phrase' : 'Edit quick phrase',
                style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Label *',
                      hintText: 'What the chip should display',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kibembeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Kibembe phrase *',
                      hintText: 'Mbote na bino nyonso na quiz!',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: englishController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'English phrase *',
                      hintText: 'Welcome to the quiz everyone!',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withAlpha((0.1 * 255).round())),
                  const SizedBox(height: 12),
                  const Text(
                    'Pronunciation voice note',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: toggleRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.mic,
                            color: Colors.black),
                        label: Text(
                            isRecording ? 'Stop recording' : 'Record note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.black,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isRecording ? null : pickAudioFile,
                        icon: const Icon(Icons.upload_file,
                            color: Color(0xFF26C6DA)),
                        label: const Text('Upload audio',
                            style: TextStyle(color: Color(0xFF26C6DA))),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF26C6DA))),
                      ),
                      if (audioBase64 != null)
                        OutlinedButton.icon(
                          onPressed:
                              isPreviewPlaying ? stopPreview : playPreview,
                          icon: Icon(
                              isPreviewPlaying
                                  ? Icons.stop_circle
                                  : Icons.volume_up,
                              color: const Color(0xFFFFB300)),
                          label: Text(
                              isPreviewPlaying
                                  ? 'Stop preview'
                                  : 'Play preview',
                              style: const TextStyle(color: Color(0xFFFFB300))),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFFB300))),
                        ),
                      if (audioBase64 != null)
                        TextButton.icon(
                          onPressed: isRecording ? null : removeAudio,
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF5350)),
                          label: const Text('Remove',
                              style: TextStyle(color: Color(0xFFEF5350))),
                        ),
                    ],
                  ),
                  if (isRecording) ...[
                    const SizedBox(height: 8),
                    const Text('Recording... tap stop when done.',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ] else if (audioBase64 != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _audioStatusLabel(audioMimeType),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await stopRecordingIfActive();

                  final label = labelController.text.trim();
                  final kibembe = kibembeController.text.trim();
                  final english = englishController.text.trim();

                  if (label.isEmpty || kibembe.isEmpty || english.isEmpty) {
                    _showSnack('Fill label, Kibembe, and English fields.');
                    return;
                  }

                  final phrase = TranslatorQuickPhrase(
                    id: existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    label: label,
                    translations: {
                      'Kibembe': kibembe,
                      'English': english,
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                    audioBase64: audioBase64,
                    audioMimeType: audioMimeType,
                  );

                  if (existing == null) {
                    await _store.addQuickPhrase(phrase);
                  } else {
                    await _store.updateQuickPhrase(phrase);
                  }

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5)),
                child: Text(existing == null ? 'Add phrase' : 'Save changes'),
              ),
            ],
          );
        },
      ),
    );

    dialogMounted = false;
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
    await recorder.dispose();
    await audioPlayer.stop();
    await audioPlayer.dispose();
  }

  Future<void> _confirmDeleteQuickPhrase(TranslatorQuickPhrase phrase) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete quick phrase?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove "${phrase.label}" from quick phrases?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.deleteQuickPhrase(phrase.id);
    }
  }

  Future<void> _showDictionaryEntryDialog(
      {TranslatorDictionaryEntry? existing}) async {
    String sourceLanguage = existing?.sourceLanguage ?? 'English';
    final termController = TextEditingController(text: existing?.term ?? '');
    final englishController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.sourceLanguage == 'English'
              ? existing.term
              : existing.translations['English'] ?? ''),
    );
    final kibembeController = TextEditingController(
      text: existing == null
          ? ''
          : (existing.sourceLanguage == 'Kibembe'
              ? existing.term
              : existing.translations['Kibembe'] ?? ''),
    );
    final partOfSpeechController =
        TextEditingController(text: existing?.partOfSpeech ?? '');
    final exampleController =
        TextEditingController(text: existing?.example ?? '');
    String? audioBase64 = existing?.audioBase64;
    String? audioMimeType = existing?.audioMimeType;

    const languages = ['English', 'Kibembe'];

    final recorder = AudioRecorder();
    final audioPlayer = AudioPlayer();
    bool dialogMounted = true;
    bool isRecording = false;
    bool isPreviewPlaying = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> stopRecordingIfActive() async {
            if (!await recorder.isRecording()) {
              return;
            }
            final path = await recorder.stop();
            if (path == null) {
              setDialogState(() => isRecording = false);
              return;
            }
            try {
              final file = io.File(path);
              final bytes = await file.readAsBytes();
              try {
                await file.delete();
              } catch (_) {}
              setDialogState(() {
                audioBase64 = base64Encode(bytes);
                audioMimeType = 'audio/aac';
                isRecording = false;
              });
            } catch (_) {
              _showSnack('Unable to save recording.');
              setDialogState(() => isRecording = false);
            }
          }

          Future<void> toggleRecording() async {
            if (isRecording) {
              await stopRecordingIfActive();
              return;
            }
            if (kIsWeb) {
              _showSnack('Recording is not supported in the browser.');
              return;
            }
            if (!await recorder.hasPermission()) {
              _showSnack('Microphone permission denied.');
              return;
            }
            try {
              final tempPath =
                  '${io.Directory.systemTemp.path}${io.Platform.pathSeparator}learn_dictionary_${DateTime.now().millisecondsSinceEpoch}.m4a';
              await recorder.start(
                const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: 128000,
                  sampleRate: 44100,
                ),
                path: tempPath,
              );
              setDialogState(() {
                isRecording = true;
                audioBase64 = null;
                audioMimeType = null;
                isPreviewPlaying = false;
              });
            } catch (_) {
              _showSnack('Failed to start recording.');
            }
          }

          Future<void> pickAudioFile() async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.audio,
                allowMultiple: false,
                withData: true,
              );
              if (result == null || result.files.isEmpty) {
                return;
              }
              final file = result.files.single;
              final bytes = file.bytes ??
                  (file.path != null
                      ? await io.File(file.path!).readAsBytes()
                      : null);
              if (bytes == null) {
                _showSnack('Could not read the selected file.');
                return;
              }
              await audioPlayer.stop();
              setDialogState(() {
                audioBase64 = base64Encode(bytes);
                audioMimeType = _inferMimeType(file.extension) ?? 'audio/mpeg';
                isPreviewPlaying = false;
                isRecording = false;
              });
            } catch (_) {
              _showSnack('Failed to import audio file.');
            }
          }

          Future<void> playPreview() async {
            if (audioBase64 == null || isPreviewPlaying) {
              return;
            }
            try {
              await audioPlayer.stop();
              final bytes = base64Decode(audioBase64!);
              await audioPlayer.play(BytesSource(bytes));
              setDialogState(() => isPreviewPlaying = true);
              audioPlayer.onPlayerComplete.first.then((_) {
                if (!dialogMounted) return;
                setDialogState(() => isPreviewPlaying = false);
              });
            } catch (_) {
              _showSnack('Unable to play the voice note.');
              setDialogState(() => isPreviewPlaying = false);
            }
          }

          Future<void> stopPreview() async {
            await audioPlayer.stop();
            setDialogState(() => isPreviewPlaying = false);
          }

          Future<void> removeAudio() async {
            await audioPlayer.stop();
            setDialogState(() {
              audioBase64 = null;
              audioMimeType = null;
              isPreviewPlaying = false;
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
                existing == null
                    ? 'Add dictionary entry'
                    : 'Edit dictionary entry',
                style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source language',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: sourceLanguage,
                    dropdownColor: const Color(0xFF0A1628),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0x33000000),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    iconEnabledColor: Colors.white70,
                    style: const TextStyle(color: Colors.white),
                    items: languages
                        .map((language) => DropdownMenuItem(
                              value: language,
                              child: Text(language),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => sourceLanguage = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: termController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '$sourceLanguage term *',
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: englishController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'English translation *',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kibembeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Kibembe translation *',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partOfSpeechController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Part of speech (optional)',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: exampleController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Example sentence (optional)',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withAlpha((0.1 * 255).round())),
                  const SizedBox(height: 12),
                  const Text(
                    'Pronunciation voice note',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: toggleRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.mic,
                            color: Colors.black),
                        label: Text(
                            isRecording ? 'Stop recording' : 'Record note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.black,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: isRecording ? null : pickAudioFile,
                        icon: const Icon(Icons.upload_file,
                            color: Color(0xFF26C6DA)),
                        label: const Text('Upload audio',
                            style: TextStyle(color: Color(0xFF26C6DA))),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF26C6DA))),
                      ),
                      if (audioBase64 != null)
                        OutlinedButton.icon(
                          onPressed:
                              isPreviewPlaying ? stopPreview : playPreview,
                          icon: Icon(
                              isPreviewPlaying
                                  ? Icons.stop_circle
                                  : Icons.volume_up,
                              color: const Color(0xFFFFB300)),
                          label: Text(
                              isPreviewPlaying
                                  ? 'Stop preview'
                                  : 'Play preview',
                              style: const TextStyle(color: Color(0xFFFFB300))),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFFB300))),
                        ),
                      if (audioBase64 != null)
                        TextButton.icon(
                          onPressed: isRecording ? null : removeAudio,
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF5350)),
                          label: const Text('Remove',
                              style: TextStyle(color: Color(0xFFEF5350))),
                        ),
                    ],
                  ),
                  if (isRecording) ...[
                    const SizedBox(height: 8),
                    const Text('Recording... tap stop when done.',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ] else if (audioBase64 != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _audioStatusLabel(audioMimeType),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await stopRecordingIfActive();

                  final term = termController.text.trim();
                  final english = englishController.text.trim();
                  final kibembe = kibembeController.text.trim();

                  if (term.isEmpty || english.isEmpty || kibembe.isEmpty) {
                    _showSnack('Fill the term and both translations.');
                    return;
                  }

                  final translations = <String, String>{
                    'English': english,
                    'Kibembe': kibembe,
                  };

                  if (sourceLanguage == 'English') {
                    translations['Kibembe'] = kibembe;
                  } else {
                    translations['English'] = english;
                  }

                  final entry = TranslatorDictionaryEntry(
                    id: existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    sourceLanguage: sourceLanguage,
                    term: term,
                    translations: translations,
                    partOfSpeech: partOfSpeechController.text.trim().isEmpty
                        ? null
                        : partOfSpeechController.text.trim(),
                    example: exampleController.text.trim().isEmpty
                        ? null
                        : exampleController.text.trim(),
                    audioBase64: audioBase64,
                    audioMimeType: audioMimeType,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );

                  if (existing == null) {
                    await _store.addTranslatorEntry(entry);
                  } else {
                    await _store.updateTranslatorEntry(entry);
                  }

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26C6DA)),
                child: Text(existing == null ? 'Add entry' : 'Save changes'),
              ),
            ],
          );
        },
      ),
    );

    dialogMounted = false;
    if (await recorder.isRecording()) {
      await recorder.stop();
    }
    await recorder.dispose();
    await audioPlayer.stop();
    await audioPlayer.dispose();
  }

  Future<void> _confirmDeleteDictionaryEntry(
      TranslatorDictionaryEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete dictionary entry?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove "${entry.term}" and its translations?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _store.deleteTranslatorEntry(entry.id);
    }
  }

  Future<void> _navigateToQuestions(QuizEvent event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminQuizQuestionsScreen(event: event)),
    );
  }

  void _openContentManager() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminContentScreen()),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
      ),
    );
  }

  String formatQuizEventDate(DateTime dateTime) => _formatDateTime(dateTime);

  String _formatDateTime(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final time = TimeOfDay.fromDateTime(dateTime);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$day $month • $hour:$minute $period';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₦₲${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '₦₲${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₦₲${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withAlpha((0.04 * 255).round()),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
        color: Colors.white.withAlpha((0.05 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
