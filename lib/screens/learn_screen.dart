import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learn_models.dart';
import '../services/betting_data_store.dart';
import '../services/learn_data_store.dart';
import 'learn/word_game_sheets.dart';
import 'quiz_play_screen.dart';
import 'quiz_pre_video_screen.dart';

String formatQuizEventDate(DateTime date) {
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
  final month = months[date.month - 1];
  final day = date.day;
  final suffix = _ordinalSuffix(day);
  final time = TimeOfDay.fromDateTime(date);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$month $day$suffix - $hour:$minute $period';
}

class _TranslationSuggestion {
  _TranslationSuggestion({
    required this.originalToken,
    required this.suggestedTerm,
    required this.entry,
    required this.distance,
    this.translation,
  });

  final String originalToken;
  final String suggestedTerm;
  final TranslatorDictionaryEntry entry;
  final int distance;
  final String? translation;
}

class _PhraseSegment {
  const _PhraseSegment({required this.text, required this.isWord});

  final String text;
  final bool isWord;
}

class _SegmentTranslation {
  const _SegmentTranslation({
    required this.output,
    required this.translated,
    this.entry,
  });

  final String output;
  final bool translated;
  final TranslatorDictionaryEntry? entry;
}

class _AudioClip {
  const _AudioClip({required this.base64Data, this.mimeType});

  final String base64Data;
  final String? mimeType;
}

class _ComposedOutput {
  const _ComposedOutput({required this.text, required this.audioClips});

  final String text;
  final List<_AudioClip> audioClips;
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) {
    return 'th';
  }
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  static const _background = Color(0xFF0A1628);

  final LearnDataStore _learnStore = LearnDataStore.instance;
  final BettingDataStore _walletStore = BettingDataStore.instance;
  AudioPlayer? _audioPlayer;

  bool _isInitializing = true;
  int _currentTab = 0;
  String _userName = 'Quiz Player';
  String _profileId = '';
  double _balance = 0;
  double _totalWinnings = 0;
  String? _selectedCategory = 'All Quizzes';

  List<QuizEvent> _events = <QuizEvent>[];
  List<QuizCategory> _categories = <QuizCategory>[];
  List<String> _translatorLanguages = <String>[];
  List<String> _disabledLanguages = <String>[];
  List<TranslatorQuickPhrase> _quickPhrases = <TranslatorQuickPhrase>[];
  List<TranslatorWordGame> _wordGames = <TranslatorWordGame>[];
  TranslatorContributorProfile? _contributorProfile;
  List<TranslatorContributorSubmission> _myContributions =
      <TranslatorContributorSubmission>[];

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Kibembe';

  final TextEditingController _translatorInputController =
      TextEditingController();

  TranslatorDictionaryEntry? _activeEntry;
  String? _translatorStatus;
  String? _quickResult;
  String? _composedResult;
  bool _translatorBusy = false;
  List<_TranslationSuggestion> _suggestions = <_TranslationSuggestion>[];
  static final RegExp _segmentSplitter = RegExp(r'(\s+)', unicode: true);
  static final RegExp _affixPattern =
      RegExp(r"^([^\p{L}\d]*)([\p{L}\d'\-]+)([^\p{L}\d]*)$", unicode: true);
  bool _isPlayingPronunciation = false;
  String? _pronunciationSourceId;
  List<_AudioClip> _composedPronunciationClips = <_AudioClip>[];
  String? _composedPronunciationKey;
  List<_AudioClip> _pendingClipQueue = <_AudioClip>[];

  final Map<String, String> _categoryBlurbs = const {
    'Football Quiz': 'Legends, tactics, and rivalries in quick-fire rounds.',
    'Geography Quiz': 'Capitals, landmarks, and map mastery on the clock.',
    'Politics Quiz': 'Policy, elections, and civic history questions.',
    'General Quiz': 'General knowledge sprints built for bragging rights.',
    'Map Quiz': 'Pin locations faster than the competition.',
  };

  final List<Map<String, dynamic>> _leaderboard = <Map<String, dynamic>>[
    {
      'name': 'Adeola A.',
      'flag': 'NG',
      'prize': 1250.0,
      'accuracy': 96,
      'rank': 1,
      'eventTitle': 'General Knowledge Clash',
      'isUser': false,
    },
    {
      'name': 'Lindiwe M.',
      'flag': 'ZA',
      'prize': 1120.0,
      'accuracy': 92,
      'rank': 2,
      'eventTitle': 'Geography Sprint',
      'isUser': false,
    },
    {
      'name': 'You',
      'flag': 'NG',
      'prize': 980.0,
      'accuracy': 88,
      'rank': 3,
      'eventTitle': 'Admin Showcase',
      'isUser': true,
    },
    {
      'name': 'Kwame B.',
      'flag': 'GH',
      'prize': 870.0,
      'accuracy': 85,
      'rank': 4,
      'eventTitle': 'Football Quiz',
      'isUser': false,
    },
    {
      'name': 'Zuri K.',
      'flag': 'KE',
      'prize': 790.0,
      'accuracy': 83,
      'rank': 5,
      'eventTitle': 'Politics Quiz',
      'isUser': false,
    },
    {
      'name': 'Fatou S.',
      'flag': 'SN',
      'prize': 710.0,
      'accuracy': 81,
      'rank': 6,
      'eventTitle': 'Map Quiz',
      'isUser': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _learnStore.addListener(_handleStoreChanged);
    _audioPlayer = AudioPlayer();
    _audioPlayer?.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      _handleAudioComplete();
    });
    _initData();
  }

  @override
  void dispose() {
    _translatorInputController.dispose();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _learnStore.removeListener(_handleStoreChanged);
    super.dispose();
  }

  Future<void> _initData() async {
    if (mounted && _isInitializing) {
      setState(() => _isInitializing = false);
    }
    await _ensureStoreReady();
    await _loadProfile();
    if (!mounted) return;
    _syncFromStore();
  }

  Future<void> _ensureStoreReady() async {
    if (_learnStore.events.isEmpty || _learnStore.categories.isEmpty) {
      await _learnStore.loadData();
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString('learn_profile_id');
    if (profileId == null || profileId.isEmpty) {
      final generatedId = 'learner-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('learn_profile_id', generatedId);
      _profileId = generatedId;
    } else {
      _profileId = profileId;
    }
    setState(() {
      _userName = prefs.getString('learn_profile_name') ?? 'Quiz Player';
      _balance =
          prefs.getDouble('learn_profile_balance') ?? _walletStore.balance;
      _totalWinnings = prefs.getDouble('learn_total_winnings') ?? 0;
      _updateUserLeaderboardName(_userName);
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (_profileId.isEmpty) {
      final generatedId = 'learner-${DateTime.now().millisecondsSinceEpoch}';
      _profileId = generatedId;
      await prefs.setString('learn_profile_id', generatedId);
    }
    await prefs.setString('learn_profile_name', _userName);
    await prefs.setDouble('learn_profile_balance', _balance);
    await prefs.setDouble('learn_total_winnings', _totalWinnings);
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }
    _syncFromStore();
  }

  void _syncFromStore() {
    final availability =
        Map<String, bool>.from(_learnStore.translatorLanguages);
    final enabledLanguages = availability.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    if (enabledLanguages.isEmpty) {
      enabledLanguages.addAll(['English', 'Kibembe']);
    }

    const preferredLanguages = ['English', 'Kibembe'];
    final filteredEnabled = <String>[];
    for (final language in preferredLanguages) {
      if (enabledLanguages.contains(language)) {
        filteredEnabled.add(language);
      }
    }
    if (filteredEnabled.isEmpty) {
      filteredEnabled.add('English');
    }
    if (!filteredEnabled.contains('English')) {
      filteredEnabled.insert(0, 'English');
    }
    final filteredDisabled = preferredLanguages
        .where((language) => !filteredEnabled.contains(language))
        .toList();

    final categories =
        _learnStore.categories.where((category) => category.isActive).toList();
    final events = List<QuizEvent>.from(_learnStore.events)
      ..sort((a, b) => a.date.compareTo(b.date));

  final contributorProfile =
    _profileId.isEmpty ? null : _learnStore.profileForUser(_profileId);
  final myContributions = contributorProfile == null
    ? <TranslatorContributorSubmission>[]
    : _learnStore.submissionsForContributor(contributorProfile.id);
  final wordGames = _learnStore.wordGames
      .where((game) => game.isActive && game.prompts.isNotEmpty)
      .toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  setState(() {
      _translatorLanguages = filteredEnabled;
      _disabledLanguages = filteredDisabled;
      _sourceLanguage =
          _resolveLanguagePreference(_sourceLanguage, filteredEnabled);
      _targetLanguage = _resolveLanguagePreference(
          _targetLanguage, filteredEnabled,
          exclude: _sourceLanguage);
      _categories = categories;
      _events = events;
      _quickPhrases =
          List<TranslatorQuickPhrase>.from(_learnStore.quickPhrases);
      _selectedCategory ??= 'All Quizzes';
    _contributorProfile = contributorProfile;
    _myContributions = myContributions;
    _wordGames = wordGames;
    });
  }

  String _resolveLanguagePreference(String preferred, List<String> languages,
      {String? exclude}) {
    if (preferred.isNotEmpty &&
        languages.contains(preferred) &&
        preferred != exclude) {
      return preferred;
    }
    for (final language in languages) {
      if (language != exclude) {
        return language;
      }
    }
    return languages.first;
  }

  String _formatCurrency(double amount) {
    if (amount == 0) {
      return '0.00';
    }
    final absolute = amount.abs();
    final formatted = absolute % 1 == 0
        ? absolute.toStringAsFixed(0)
        : absolute.toStringAsFixed(2);
    return amount < 0 ? '-$formatted' : formatted;
  }

  void _updateUserLeaderboardName(String name) {
    final index = _leaderboard.indexWhere((user) => user['isUser'] == true);
    if (index != -1) {
      _leaderboard[index]['name'] = name;
    }
  }

  void _recordQuizOutcome(QuizEvent event, QuizSessionResult result) {
    final percent = result.maxScore == 0
        ? 0
        : ((result.score / result.maxScore) * 100).round();
  final payoutRaw = (event.prize * percent / 100).clamp(0, double.infinity);
  final payout = double.parse(payoutRaw.toStringAsFixed(2));

    final bool shouldCreditWallet = payout > 0;

    setState(() {
      if (shouldCreditWallet) {
        _totalWinnings += payout;
        _balance += payout;
      }

      final index = _leaderboard.indexWhere((user) => user['isUser'] == true);
      if (index != -1) {
        final updated = Map<String, dynamic>.from(_leaderboard[index]);
        updated['name'] = _userName;
        updated['prize'] = payout;
        updated['accuracy'] = percent;
        updated['eventTitle'] = event.title;
        _leaderboard[index] = updated;
      } else {
        _leaderboard.add({
          'name': _userName,
          'flag': 'NG',
          'prize': payout,
          'accuracy': percent,
          'eventTitle': event.title,
          'isUser': true,
        });
      }

      _leaderboard.sort((a, b) {
        final prizeA = (a['prize'] as num?)?.toDouble() ?? 0;
        final prizeB = (b['prize'] as num?)?.toDouble() ?? 0;
        return prizeB.compareTo(prizeA);
      });
      for (var i = 0; i < _leaderboard.length; i++) {
        _leaderboard[i]['rank'] = i + 1;
      }
    });

    if (shouldCreditWallet) {
      _walletStore.adjustBalance(payout);
    }
    _saveProfile();
  }

  List<QuizEvent> _filteredEvents() {
    if (_selectedCategory == null || _selectedCategory == 'All Quizzes') {
      return _events;
    }
    return _events
        .where(
          (event) => event.categories.any(
            (category) =>
                category.toLowerCase() == _selectedCategory!.toLowerCase(),
          ),
        )
        .toList();
  }

  void _runDictionaryLookup() {
    // Dictionary feature removed.
  }

  Future<void> _performTranslate({TranslatorQuickPhrase? fallback}) async {
    final term = _translatorInputController.text.trim();
    if (term.isEmpty) {
      setState(() {
        _activeEntry = null;
        _quickResult = null;
        _composedResult = null;
        _suggestions = <_TranslationSuggestion>[];
        _translatorStatus = 'Type a phrase to translate.';
      });
      return;
    }

    setState(() {
      _translatorBusy = true;
      _translatorStatus = null;
      _quickResult = null;
      _composedResult = null;
      _suggestions = <_TranslationSuggestion>[];
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (!mounted) {
      return;
    }

    final entry =
        _learnStore.findDictionaryEntry(term, sourceLanguage: _sourceLanguage);
    final suggestions = <_TranslationSuggestion>[];
    _ComposedOutput? composedOutput;
    String? composedKey;
    String? nextSourceId;

    if (entry == null) {
      composedOutput = _composeTranslation(term, suggestions);
      if (composedOutput != null &&
          composedOutput.audioClips.isNotEmpty &&
          composedOutput.text.isNotEmpty) {
        composedKey = 'compose-${DateTime.now().microsecondsSinceEpoch}';
        nextSourceId = composedKey;
      }
    } else {
      nextSourceId = entry.id;
    }

    if (suggestions.isNotEmpty) {
      suggestions.sort((a, b) {
        final distanceCompare = a.distance.compareTo(b.distance);
        if (distanceCompare != 0) {
          return distanceCompare;
        }
        return a.suggestedTerm
            .toLowerCase()
            .compareTo(b.suggestedTerm.toLowerCase());
      });
    }

    final trimmedSuggestions = suggestions.length > 6
        ? suggestions.sublist(0, 6)
        : List<_TranslationSuggestion>.from(suggestions);

    bool resetPronunciation = false;
    if (_isPlayingPronunciation) {
      final player = _audioPlayer;
      final shouldStop =
          nextSourceId == null || nextSourceId != _pronunciationSourceId;
      if (shouldStop) {
        if (player != null) {
          await player.stop();
        }
        _pendingClipQueue = <_AudioClip>[];
        resetPronunciation = true;
      }
    }

    final quickPhraseRaw = fallback?.textFor(_targetLanguage);
    final quickPhraseText = quickPhraseRaw?.trim();

    setState(() {
      _translatorBusy = false;
      _activeEntry = entry;
      if (entry != null) {
        _quickResult = null;
        _composedResult = null;
        _composedPronunciationClips = <_AudioClip>[];
        _composedPronunciationKey = null;
        _suggestions = <_TranslationSuggestion>[];
        _translatorStatus = null;
        if (resetPronunciation || _pronunciationSourceId != entry.id) {
          _isPlayingPronunciation = false;
          _pronunciationSourceId = null;
          _pendingClipQueue = <_AudioClip>[];
        }
        return;
      }

      _composedResult = composedOutput?.text;
      _composedPronunciationClips =
          composedOutput?.audioClips ?? <_AudioClip>[];
      _composedPronunciationKey = _composedPronunciationClips.isEmpty
          ? null
          : composedKey ?? 'compose-${DateTime.now().millisecondsSinceEpoch}';
      _quickResult = quickPhraseText?.isEmpty ?? true ? null : quickPhraseText;
      _suggestions = trimmedSuggestions;
      if (resetPronunciation) {
        _isPlayingPronunciation = false;
        _pronunciationSourceId = null;
        _pendingClipQueue = <_AudioClip>[];
      }
      if (_composedPronunciationClips.isEmpty && !resetPronunciation) {
        _isPlayingPronunciation = false;
        _pronunciationSourceId = null;
      }

      if (_composedResult != null && _suggestions.isNotEmpty) {
        _translatorStatus =
            'Showing combined translation. Similar words appear below.';
      } else if (_composedResult != null) {
        _translatorStatus = 'Showing combined translation from saved words.';
      } else if (_quickResult != null) {
        _translatorStatus = 'Quick phrase preview.';
      } else if (_suggestions.isNotEmpty) {
        _translatorStatus =
            'No exact match for "$term". Try one of the suggested words below.';
      } else {
        _translatorStatus = 'No saved translations for "$term".';
      }
    });
  }

  Future<void> _applySuggestion(_TranslationSuggestion suggestion) async {
    final didReplace = _replaceTokenInInput(
        suggestion.originalToken, suggestion.suggestedTerm);
    if (!didReplace) {
      final replacement = suggestion.suggestedTerm;
      _translatorInputController.value = TextEditingValue(
        text: replacement,
        selection: TextSelection.collapsed(offset: replacement.length),
      );
    }
    await _performTranslate();
  }

  bool _replaceTokenInInput(String original, String replacement) {
    final pattern =
        RegExp('\\b${RegExp.escape(original)}\\b', caseSensitive: false);
    final current = _translatorInputController.text;
    if (!pattern.hasMatch(current)) {
      return false;
    }
    final updated = current.replaceFirst(pattern, replacement);
    _translatorInputController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
    return true;
  }

  Future<void> _applyQuickPhrase(TranslatorQuickPhrase phrase) async {
    final sourceText =
        phrase.translations[_sourceLanguage] ?? phrase.textFor(_sourceLanguage);
    _translatorInputController.text = sourceText;
    setState(() {
      _translatorStatus = null;
    });
    await _performTranslate(fallback: phrase);
  }

  void _handleAudioComplete() {
    if (_pendingClipQueue.isNotEmpty) {
      Future.microtask(_startClipPlayback);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlayingPronunciation = false;
      _pronunciationSourceId = null;
    });
  }

  Future<void> _startClipPlayback() async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }

    if (_pendingClipQueue.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayingPronunciation = false;
        _pronunciationSourceId = null;
      });
      return;
    }

    final clip = _pendingClipQueue.removeAt(0);
    try {
      final bytes = base64Decode(clip.base64Data);
      await player.play(BytesSource(bytes));
    } catch (_) {
      if (_pendingClipQueue.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlayingPronunciation = false;
          _pronunciationSourceId = null;
        });
      } else {
        await _startClipPlayback();
      }
    }
  }

  String _formatSuggestionLabel(_TranslationSuggestion suggestion) {
    final translation = suggestion.translation;
    if (translation == null || translation.isEmpty) {
      return suggestion.suggestedTerm;
    }
    return '${suggestion.suggestedTerm} · $translation';
  }

  Widget _buildLanguageSwapButton() {
    return Material(
      color: const Color(0xFF00BFA5).withAlpha(60),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _swapLanguages,
        child: const Center(
          child: Icon(Icons.swap_horiz, color: Color(0xFF00BFA5)),
        ),
      ),
    );
  }

  String? _translationForEntry(
      TranslatorDictionaryEntry entry, String language) {
    final normalizedLanguage = language.toLowerCase();
    if (entry.sourceLanguage.toLowerCase() == normalizedLanguage) {
      final term = entry.term.trim();
      return term.isEmpty ? null : term;
    }

    final direct = entry.translations[language];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    for (final candidate in entry.translations.entries) {
      if (candidate.key.toLowerCase() == normalizedLanguage) {
        final value = candidate.value.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  _ComposedOutput? _composeTranslation(
      String input, List<_TranslationSuggestion> sink) {
    final segments = _splitIntoSegments(input);
    if (segments.isEmpty) {
      return null;
    }

    final normalizedSource = _sourceLanguage.toLowerCase();
    final entries =
        _learnStore.entriesForLanguage(_sourceLanguage).where((entry) {
      if (entry.sourceLanguage.toLowerCase() == normalizedSource) {
        return true;
      }
      return entry.translations.keys
          .any((lang) => lang.toLowerCase() == normalizedSource);
    }).toList();

    if (entries.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    var translated = false;
    final clips = <_AudioClip>[];

    for (final segment in segments) {
      if (!segment.isWord) {
        buffer.write(segment.text);
        continue;
      }

      final result = _translateSegment(segment.text, entries, sink);
      buffer.write(result.output);
      if (result.translated) {
        translated = true;
        final entry = result.entry;
        final base64Audio = entry?.audioBase64;
        if (base64Audio != null && base64Audio.isNotEmpty) {
          clips.add(
            _AudioClip(
              base64Data: base64Audio,
              mimeType: entry?.audioMimeType,
            ),
          );
        }
      }
    }

    if (!translated) {
      return null;
    }

    return _ComposedOutput(
      text: buffer.toString().trimRight(),
      audioClips: clips,
    );
  }

  List<_PhraseSegment> _splitIntoSegments(String input) {
    final segments = <_PhraseSegment>[];
    var index = 0;

    for (final match in _segmentSplitter.allMatches(input)) {
      if (match.start > index) {
        segments.add(_PhraseSegment(
            text: input.substring(index, match.start), isWord: true));
      }
      final whitespace = match.group(0) ?? '';
      segments.add(_PhraseSegment(text: whitespace, isWord: false));
      index = match.end;
    }

    if (index < input.length) {
      segments.add(_PhraseSegment(text: input.substring(index), isWord: true));
    }

    return segments;
  }

  _SegmentTranslation _translateSegment(
    String token,
    List<TranslatorDictionaryEntry> entries,
    List<_TranslationSuggestion> suggestions,
  ) {
    final match = _affixPattern.firstMatch(token);
    if (match == null) {
      return _SegmentTranslation(output: token, translated: false);
    }

    final leading = match.group(1) ?? '';
    final core = match.group(2) ?? '';
    final trailing = match.group(3) ?? '';

    if (core.isEmpty) {
      return _SegmentTranslation(output: token, translated: false);
    }

    final entry = _findExactEntry(core, entries);
    if (entry != null) {
      final translated = _translationForEntry(entry, _targetLanguage);
      if (translated != null && translated.isNotEmpty) {
        return _SegmentTranslation(
          output: '$leading$translated$trailing',
          translated: translated.toLowerCase() != core.toLowerCase(),
          entry: entry,
        );
      }
    }

    final suggestion = _buildSuggestion(core, entries);
    if (suggestion != null) {
      final alreadyAdded = suggestions.any(
        (existing) =>
            existing.suggestedTerm.toLowerCase() ==
            suggestion.suggestedTerm.toLowerCase(),
      );
      if (!alreadyAdded) {
        suggestions.add(suggestion);
      }

      final suggestionTranslation = suggestion.translation;
      if (suggestionTranslation != null && suggestionTranslation.isNotEmpty) {
        return _SegmentTranslation(
          output: '$leading$suggestionTranslation$trailing',
          translated: true,
          entry: suggestion.entry,
        );
      }
    }

    return _SegmentTranslation(output: token, translated: false);
  }

  TranslatorDictionaryEntry? _findExactEntry(
    String token,
    List<TranslatorDictionaryEntry> entries,
  ) {
    final normalizedToken = token.trim().toLowerCase();
    if (normalizedToken.isEmpty) {
      return null;
    }

    final normalizedSource = _sourceLanguage.toLowerCase();

    for (final entry in entries) {
      if (entry.sourceLanguage.toLowerCase() == normalizedSource &&
          entry.term.trim().toLowerCase() == normalizedToken) {
        return entry;
      }

      for (final translation in entry.translations.entries) {
        if (translation.key.toLowerCase() == normalizedSource &&
            translation.value.trim().toLowerCase() == normalizedToken) {
          return entry;
        }
      }
    }

    return null;
  }

  _TranslationSuggestion? _buildSuggestion(
    String token,
    List<TranslatorDictionaryEntry> entries,
  ) {
    final normalizedToken = token.trim().toLowerCase();
    if (normalizedToken.isEmpty) {
      return null;
    }

    final normalizedSource = _sourceLanguage.toLowerCase();
    TranslatorDictionaryEntry? bestEntry;
    int? bestDistance;

    for (final entry in entries) {
      if (entry.sourceLanguage.toLowerCase() != normalizedSource) {
        continue;
      }

      final candidateTerm = entry.term.trim();
      if (candidateTerm.isEmpty) {
        continue;
      }

      final distance =
          _levenshteinDistance(normalizedToken, candidateTerm.toLowerCase());
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestEntry = entry;
        if (distance == 0) {
          break;
        }
      }
    }

    if (bestEntry == null || bestDistance == null) {
      return null;
    }

    if (bestDistance == 0) {
      return null;
    }

    final allowedDistance = normalizedToken.length <= 4 ? 1 : 2;
    if (bestDistance > allowedDistance) {
      return null;
    }

    final translation = _translationForEntry(bestEntry, _targetLanguage);

    return _TranslationSuggestion(
      originalToken: token,
      suggestedTerm: bestEntry.term,
      translation: translation,
      entry: bestEntry,
      distance: bestDistance,
    );
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + cost,
        );
      }

      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  void _swapLanguages() {
    setState(() {
      final previousSource = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = _resolveLanguagePreference(
          previousSource, _translatorLanguages,
          exclude: _sourceLanguage);
    });
    _runDictionaryLookup();
    if (_translatorInputController.text.trim().isNotEmpty) {
      _performTranslate();
    }
  }

  void _handleCategoryTap(String? categoryName) {
    setState(() {
      _selectedCategory = categoryName;
    });
    final event = _findEventForCategory(categoryName);
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No quiz is ready for that category yet.'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
    }
  }

  QuizEvent? _findEventForCategory(String? categoryName) {
    if (categoryName == null || categoryName == 'All Quizzes') {
      return _events.isNotEmpty ? _events.first : null;
    }
    for (final event in _events) {
      if (event.categories.any(
          (category) => category.toLowerCase() == categoryName.toLowerCase())) {
        return event;
      }
    }
    return null;
  }

  Future<void> _playQuiz(QuizEvent event) async {
    if (!mounted) return;

    if (event.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This quiz is still being prepared. Check back soon!'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    if (event.preQuizVideoUrl != null &&
        event.preQuizVideoUrl!.trim().isNotEmpty) {
      final watched = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => QuizPreVideoScreen(event: event)),
      );
      if (!mounted || watched != true) {
        return;
      }
    }

    final result = await Navigator.of(context).push<QuizSessionResult>(
      MaterialPageRoute(builder: (_) => QuizPlayScreen(event: event)),
    );
    if (!mounted || result == null) {
      return;
    }
    final percent = result.maxScore == 0
        ? 0
        : ((result.score / result.maxScore) * 100).round();
  final rawEarned = (event.prize * percent / 100).clamp(0, double.infinity);
  final earned = double.parse(rawEarned.toStringAsFixed(2));
    _recordQuizOutcome(event, result);
  final earningsNote = earned > 0
    ? ' • Earned ₦₲ ${_formatCurrency(earned)}'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: event.color,
        content: Text(
            'You scored ${result.score}/${result.maxScore} • $percent% correct$earningsNote'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
        ),
      );
    }

    final tabs = [
      _buildHomeTab(),
      _buildTranslateTab(),
      _buildGamesTab(),
      _buildRankingTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground()),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: tabs[_currentTab],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A1628),
            Color(0xFF0D1D33),
            Color(0xFF061122),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final filters = <String>['All Quizzes', ..._categories.map((e) => e.name)];
    final events = _filteredEvents();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(45)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filters.map((filter) {
                    final isSelected = _selectedCategory == filter ||
                        (_selectedCategory == null && filter == 'All Quizzes');
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => _handleCategoryTap(filter),
                        selectedColor: const Color(0xFF00BFA5),
                        backgroundColor: Colors.white.withAlpha(28),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: events.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(36)),
                        ),
                        child: const Text(
                          'Admins are preparing new quizzes for this category. Check back soon!',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
          : ListView.builder(
            padding: const EdgeInsets.only(bottom: 110),
                      itemCount: events.length,
                      itemBuilder: (context, index) =>
                          _buildEventCard(events[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(QuizEvent event) {
  final accent = event.color;
  final hasThumbnail =
    event.thumbnailUrl != null && event.thumbnailUrl!.trim().isNotEmpty;
  final introClipTitle = (event.preQuizVideoTitle ?? '').trim();
  final introClipLabel =
    introClipTitle.isEmpty ? 'Warm-up clip' : introClipTitle;
  final hasIntroClip = event.preQuizVideoUrl != null &&
    event.preQuizVideoUrl!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _playQuiz(event),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasThumbnail) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildEventThumbnail(event.thumbnailUrl!.trim()),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: accent.withAlpha(60),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.subtitle,
                            style:
                                TextStyle(color: Colors.white.withAlpha(170)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed:
                      event.questions.isEmpty ? null : () => _playQuiz(event),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(event.questions.isEmpty
                      ? 'Quiz coming soon'
                      : 'Play now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (hasIntroClip) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline,
                          color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Watch "$introClipLabel" before you start.',
                          style: TextStyle(
                              color: Colors.white.withAlpha(150), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _buildEventMetaRow(event),
                if (event.categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _categoryBlurbs[event.categories.first] ??
                        'Quick-fire questions selected by admins for this category.',
                    style: TextStyle(
                        color: Colors.white.withAlpha(150), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventThumbnail(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
      );
    }
    if (uri != null && uri.hasScheme && uri.scheme == 'file' && !kIsWeb) {
      final file = io.File(uri.toFilePath());
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
        );
      }
    }
    if (!kIsWeb) {
      final file = io.File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
        );
      }
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
      );
    }
    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Image.asset(
      'assets/images/default_promo.png',
      fit: BoxFit.cover,
    );
  }

  Widget _buildEventMetaRow(QuizEvent event) {
    return Row(
      children: [
        Expanded(
          child: _buildEventMetaItem(
            Icons.calendar_today,
            formatQuizEventDate(event.date),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEventMetaItem(
            Icons.people,
            '${event.participants} joined',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEventMetaItem(
            Icons.quiz,
            '${event.questions.length} questions',
          ),
        ),
      ],
    );
  }

  Widget _buildEventMetaItem(IconData icon, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranslateTab() {
    final quickPhrases = _quickPhrases;
    final activeEntry = _activeEntry;
    final entryTranslation = activeEntry == null
        ? null
        : _translationForEntry(activeEntry, _targetLanguage);
    final translation = entryTranslation ?? _composedResult ?? _quickResult;
    String? trimmedTranslation;
    if (translation != null) {
      final candidate = translation.trim();
      if (candidate.isNotEmpty) {
        trimmedTranslation = candidate;
      }
    }
    final hasTranslation = trimmedTranslation != null;
    final displayTranslation =
        trimmedTranslation ?? 'Translation will appear here.';
    final pronunciationData = activeEntry?.audioBase64;
    final hasCombinedAudio =
        activeEntry == null && _composedPronunciationClips.isNotEmpty;
    final hasPronunciation =
        (pronunciationData != null && pronunciationData.trim().isNotEmpty) ||
            hasCombinedAudio;
    final bool isPronunciationPlaying;
    if (!hasPronunciation) {
      isPronunciationPlaying = false;
    } else if (activeEntry != null) {
      isPronunciationPlaying =
          _isPlayingPronunciation && _pronunciationSourceId == activeEntry.id;
    } else {
      isPronunciationPlaying = _isPlayingPronunciation &&
          _pronunciationSourceId == _composedPronunciationKey;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Translate',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_disabledLanguages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.redAccent.withAlpha(120)),
                ),
                child: Text(
                  'Disabled by admin: ${_disabledLanguages.join(', ')}. Choose an available language or check back later.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildLanguageSelectorRow(),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _translatorInputController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Type or paste a quiz prompt here',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(130)),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _translatorBusy ? null : () => _performTranslate(),
                      icon: _translatorBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.translate_rounded),
                      label: const Text('Translate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTranslation,
                    style: TextStyle(
                      color: hasTranslation ? Colors.white : Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasPronunciation) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _togglePronunciationPlayback(
                            entry: activeEntry,
                            bundle: hasCombinedAudio
                                ? _composedPronunciationClips
                                : null,
                            bundleKey: hasCombinedAudio
                                ? _composedPronunciationKey
                                : null,
                          ),
                          icon: Icon(isPronunciationPlaying
                              ? Icons.stop_circle
                              : Icons.volume_up),
                          label: Text(isPronunciationPlaying
                              ? 'Stop audio'
                              : 'Play pronunciation'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFB300),
                            side: const BorderSide(color: Color(0xFFFFB300)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isPronunciationPlaying
                                ? 'Playing voice notes…'
                                : hasCombinedAudio
                                    ? 'Tap play to hear the combined pronunciation.'
                                    : 'Tap play to hear the pronunciation.',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_translatorStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _translatorStatus!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Similar matches',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _suggestions
                    .map(
                      (suggestion) => ActionChip(
                        label: Text(_formatSuggestionLabel(suggestion)),
                        onPressed: _translatorBusy
                            ? null
                            : () => _applySuggestion(suggestion),
                        backgroundColor: Colors.white.withAlpha(24),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            Text('Quick phrases',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (quickPhrases.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No quick phrases yet. Ask an admin to add some in Learn Control.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: quickPhrases
                    .map(
                      (phrase) => ActionChip(
                        label: Text(phrase.label),
                        onPressed: () => _applyQuickPhrase(phrase),
                        backgroundColor: Colors.white.withAlpha(24),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesTab() {
    final games = _wordGames;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Games',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play word-powered challenges built from our Translate library.',
              style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (games.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: const Text(
                  'Games are being prepared by the admins. Check back soon for new vocabulary battles!',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )
            else
              ...games.map(_buildGameCard),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(TranslatorWordGame game) {
    final promptCount = game.promptCount;
    final bestOutOf = game.bestOutOf == 0 ? promptCount : game.bestOutOf;
    final lastPlayed = game.lastPlayedAt;
    String? lastPlayedLabel;
    if (lastPlayed != null) {
      lastPlayedLabel = formatQuizEventDate(lastPlayed);
    }
    final styleLabel = _gameStyleLabel(game);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(40)),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.description,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (promptCount == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withAlpha(60),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Needs prompts',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                )
              else if (game.playCount == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withAlpha(60),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('New',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withAlpha(70),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${game.playCount} plays',
                      style: const TextStyle(color: Colors.black, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.videogame_asset,
                    size: 18, color: Colors.black87),
                label: Text(styleLabel),
                backgroundColor: Colors.white.withAlpha(210),
                labelStyle: const TextStyle(color: Colors.black87, fontSize: 12),
              ),
              Chip(
                avatar: const Icon(Icons.text_fields, size: 18, color: Colors.black87),
                label: Text('$promptCount prompts'),
                backgroundColor: Colors.white.withAlpha(210),
                labelStyle: const TextStyle(color: Colors.black87, fontSize: 12),
              ),
              Chip(
                avatar: const Icon(Icons.emoji_events, size: 18, color: Colors.black87),
                label: Text('Best ${game.bestScore}/$bestOutOf'),
                backgroundColor: Colors.white.withAlpha(210),
                labelStyle: const TextStyle(color: Colors.black87, fontSize: 12),
              ),
              if (lastPlayedLabel != null)
                Chip(
                  avatar:
                      const Icon(Icons.history, size: 18, color: Colors.black87),
                  label: Text('Last played $lastPlayedLabel'),
                  backgroundColor: Colors.white.withAlpha(210),
                  labelStyle: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: promptCount == 0 ? null : () => _launchWordGame(game),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play now'),
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
        ],
      ),
    );
  }

  Future<void> _launchWordGame(TranslatorWordGame game) async {
    if (game.prompts.isEmpty) {
      _showProfileSnack(
        'This game is still being configured by the admins.',
        color: const Color(0xFFEF5350),
      );
      return;
    }

    final style = game.gameStyle.trim().toLowerCase();
    switch (style) {
      case 'wordle':
      case 'word-quest':
        await showWordleGameSheet(context, game, _learnStore);
        break;
      case 'word_trip':
      case 'word_builder':
      case 'scramble':
      default:
        await showScrambleGameSheet(context, game, _learnStore);
        break;
    }
  }

  String _gameStyleLabel(TranslatorWordGame game) {
    final style = game.gameStyle.trim().toLowerCase();
    switch (style) {
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

  Future<void> _togglePronunciationPlayback({
    TranslatorDictionaryEntry? entry,
    List<_AudioClip>? bundle,
    String? bundleKey,
  }) async {
    final player = _audioPlayer;
    if (player == null) {
      _showTranslateSnack('Audio player not ready.');
      return;
    }

    final String? sourceId = entry?.id ?? bundleKey;
    if (sourceId == null && (bundle == null || bundle.isEmpty)) {
      _showTranslateSnack('No voice notes available yet.');
      return;
    }

    final targetSource =
        sourceId ?? 'compose-${DateTime.now().millisecondsSinceEpoch}';
    final isCurrent =
        _isPlayingPronunciation && _pronunciationSourceId == targetSource;

    if (isCurrent) {
      await player.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayingPronunciation = false;
        _pronunciationSourceId = null;
        _pendingClipQueue = <_AudioClip>[];
      });
      return;
    }

    await player.stop();
    _pendingClipQueue = <_AudioClip>[];

    if (entry != null) {
      final base64Audio = entry.audioBase64;
      if (base64Audio == null || base64Audio.trim().isEmpty) {
        _showTranslateSnack('No pronunciation available for this word yet.');
        return;
      }

      try {
        final decoded = base64Decode(base64Audio);
        await player.play(BytesSource(decoded));
        if (!mounted) {
          await player.stop();
          return;
        }
        setState(() {
          _isPlayingPronunciation = true;
          _pronunciationSourceId = entry.id;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlayingPronunciation = false;
          _pronunciationSourceId = null;
        });
        _showTranslateSnack('Unable to play the pronunciation.');
      }
      return;
    }

    if (bundle == null || bundle.isEmpty) {
      _showTranslateSnack('No voice notes available yet.');
      return;
    }

    _pendingClipQueue = List<_AudioClip>.from(bundle);
    if (!mounted) {
      _pendingClipQueue = <_AudioClip>[];
      return;
    }
    setState(() {
      _isPlayingPronunciation = true;
      _pronunciationSourceId = targetSource;
      if (bundleKey == null) {
        _composedPronunciationKey = targetSource;
      }
    });
    await _startClipPlayback();
  }

  void _showTranslateSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLanguageSelectorRow() {
    const controlSize = 56.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Languages',
            style: TextStyle(
              color: Colors.white.withAlpha(210),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLanguageDropdown(
                  label: 'From',
                  value: _sourceLanguage,
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: SizedBox(
                  width: controlSize - 12,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: controlSize,
                      height: controlSize,
                      child: _buildLanguageSwapButton(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLanguageDropdown(
                  label: 'To',
                  value: _targetLanguage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(36)),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaderboard',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Scores refresh after every quiz round. Top players win instant rewards.',
              style: TextStyle(color: Colors.white.withAlpha(180)),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                for (final user in _leaderboard) _buildRankingCard(user),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard(Map<String, dynamic> user) {
    final isUser = user['isUser'] as bool;
    final Color baseColor = isUser ? const Color(0xFF00BFA5) : Colors.white;
    final prize = (user['prize'] as num?)?.toDouble() ?? 0;
    final accuracy = user['accuracy'] as int?;
    final eventTitle = (user['eventTitle'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser
            ? const Color(0xFF00BFA5).withAlpha(40)
            : Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: baseColor.withAlpha(120)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user['flag'] as String,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['name'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₦₲ ${_formatCurrency(prize)}',
                  style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                if (accuracy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      eventTitle != null && eventTitle.isNotEmpty
                          ? '$accuracy% accurate • $eventTitle'
                          : '$accuracy% accurate',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (user['rank'] as int) <= 3
                  ? const Color(0xFFFFD700).withAlpha(60)
                  : Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${user['rank']}',
                style: TextStyle(
                  color: (user['rank'] as int) <= 3
                      ? const Color(0xFFFFD700)
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final joinedEvents = _events.where((event) => event.joined).length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.person, size: 58, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              _userName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withAlpha(50),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF00BFA5)),
              ),
              child: Text(
                'Balance: ₦₲ ${_balance.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Color(0xFF00BFA5), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 22),
            _buildContributorCard(),
            const SizedBox(height: 28),
            _buildStatCard('Events Joined', '$joinedEvents', Icons.event),
            const SizedBox(height: 12),
      _buildStatCard('Total Winnings',
        '₦₲ ${_formatCurrency(_totalWinnings)}', Icons.emoji_events),
            const SizedBox(height: 12),
            _buildStatCard(
                'Current Rank',
                'Top ${_leaderboard.firstWhere((user) => user['isUser'] == true)['rank']} player',
                Icons.leaderboard),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showEditProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showAddFunds,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Funds'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00BFA5),
                side: const BorderSide(color: Color(0xFF00BFA5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributorCard() {
    final profile = _contributorProfile;
    Color borderColor;
    Color accentColor;
    String headline;
    String message;
    bool showRequestButton = false;
    bool showSubmitButton = false;
    bool showPendingButton = false;
    String requestLabel = 'Request contributor access';

    if (profile == null) {
      borderColor = const Color(0xFF26C6DA);
      accentColor = const Color(0xFF26C6DA).withAlpha(40);
      headline = 'Become a Translate contributor';
      message =
          'Submit a request to help expand the Translate library with your own words and voice notes.';
      showRequestButton = true;
    } else if (profile.isApproved) {
      borderColor = const Color(0xFF00BFA5);
      accentColor = const Color(0xFF00BFA5).withAlpha(40);
      headline = 'Contributor access enabled';
      message = 'Add new words and voice notes. We review every submission.';
      showSubmitButton = true;
    } else if (profile.isPending) {
      borderColor = const Color(0xFFFFB300);
      accentColor = const Color(0xFFFFB300).withAlpha(30);
      headline = 'Request under review';
      message = 'An admin will review your request soon.';
      showPendingButton = true;
    } else {
      borderColor = const Color(0xFFEF5350);
      accentColor = const Color(0xFFEF5350).withAlpha(30);
      headline = 'Request was declined';
      final rejectionReason = profile.rejectionReason;
      message = (rejectionReason != null && rejectionReason.isNotEmpty)
          ? rejectionReason
          : 'You can update your details and try again.';
      showRequestButton = true;
      requestLabel = 'Request again';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withAlpha(160)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (profile != null && profile.approvedCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Approved uploads: ${profile.approvedCount}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          if (showRequestButton)
            ElevatedButton(
              onPressed: _handleContributorRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26C6DA),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(requestLabel),
            )
          else if (showPendingButton)
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFFB300)),
                foregroundColor: const Color(0xFFFFB300),
              ),
              child: const Text('Waiting for approval'),
            )
          else if (showSubmitButton)
            ElevatedButton.icon(
              onPressed: _showContributionComposer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Submit word or phrase'),
            ),
          if (_myContributions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildContributionHistory(),
          ],
        ],
      ),
    );
  }

  Widget _buildContributionHistory() {
    final approved = _myContributions
        .where((submission) => submission.status == 'approved')
        .toList();
    final recent = approved.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent submissions',
                style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: _myContributions.isEmpty
                  ? null
                  : _showContributionHistorySheet,
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF26C6DA),
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('View history'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Approved contributions will appear here once they go live.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          ...recent.map((submission) {
            final status = submission.status;
            Color badgeColor;
            String badgeLabel;
            switch (status) {
              case 'approved':
                badgeColor = const Color(0xFF00BFA5);
                badgeLabel = 'Approved';
                break;
              case 'rejected':
                badgeColor = const Color(0xFFEF5350);
                badgeLabel = 'Rejected';
                break;
              default:
                badgeColor = const Color(0xFFFFB300);
                badgeLabel = 'Pending';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.term,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submission.translations.entries
                              .map((entry) => '${entry.key}: ${entry.value}')
                              .join(' • '),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withAlpha(150)),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, height: 1.1),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _showContributionHistorySheet() async {
    if (_myContributions.isEmpty) {
      return;
    }

    final pending = _myContributions
        .where((submission) => submission.isPending)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final approved = _myContributions
        .where((submission) => submission.status == 'approved')
        .toList()
      ..sort((a, b) =>
            (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));
    final rejected = _myContributions
        .where((submission) => submission.status == 'rejected')
        .toList()
      ..sort((a, b) =>
            (b.decidedAt ?? b.submittedAt).compareTo(a.decidedAt ?? a.submittedAt));

    await showModalBottomSheet<void>(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 42,
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
              ...pending.map(_buildContributionHistoryTile),
                          const SizedBox(height: 24),
                        ],
                        if (approved.isNotEmpty) ...[
                          Text('Approved',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
              ...approved.map(_buildContributionHistoryTile),
                          const SizedBox(height: 24),
                        ],
                        if (rejected.isNotEmpty) ...[
                          Text('Rejected',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
              ...rejected.map(_buildContributionHistoryTile),
                        ],
                        if (pending.isEmpty &&
                            approved.isEmpty &&
                            rejected.isEmpty)
                          const Text(
                            'No submissions yet.',
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

  Widget _buildContributionHistoryTile(
      TranslatorContributorSubmission submission) {
    Color accent;
    String statusLabel;
    switch (submission.status) {
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

    final backgroundAlpha = submission.status == 'rejected' ? 0.32 : 0.22;
    final borderAlpha = submission.status == 'rejected' ? 0.65 : 0.5;

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
                      'From ${submission.sourceLanguage}',
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
          const SizedBox(height: 6),
          Text(
            'Submitted ${formatQuizEventDate(submission.submittedAt)} • '
            '${submission.status == 'pending' ? 'Awaiting review' : 'Decided ${formatQuizEventDate(decisionDate)}'}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContributorRequest() async {
    if (_profileId.isEmpty) {
      await _saveProfile();
      if (!mounted) {
        return;
      }
    }

    final noteController = TextEditingController(
        text: _contributorProfile?.applicationNote ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Request contributor access',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Let the admins know why you want to help grow the Translate library.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tell us about your language expertise…',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(noteController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26C6DA),
              foregroundColor: Colors.black,
            ),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    noteController.dispose();

    if (result == null) {
      return;
    }

    await _learnStore.submitContributorRequest(
      userId: _profileId,
      displayName: _userName,
      note: result.isEmpty ? null : result,
    );

    if (!mounted) {
      return;
    }
    _showProfileSnack('Request sent. We will notify you after review.');
  }

  Future<void> _showContributionComposer() async {
    final profile = _contributorProfile;
    if (profile == null || !profile.isApproved) {
      _showProfileSnack(
        'Your contributor access is not active.',
        color: const Color(0xFFEF5350),
      );
      return;
    }

    final termController = TextEditingController();
    final translationController = TextEditingController();
    final partOfSpeechController = TextEditingController();
    final exampleController = TextEditingController();

    final availableLanguages = _translatorLanguages.isEmpty
        ? <String>['English', 'Kibembe']
        : List<String>.from(_translatorLanguages);
    String selectedSource = availableLanguages.contains('English')
        ? 'English'
        : availableLanguages.first;
    List<String> targetOptions =
        availableLanguages.where((lang) => lang != selectedSource).toList();
    if (targetOptions.isEmpty) {
      targetOptions = selectedSource == 'English'
          ? <String>['Kibembe']
          : <String>['English'];
    }
    String selectedTarget = targetOptions.first;

    String? audioBase64;
    String? audioMimeType;
    String? audioLabel;
    String? errorText;
    bool isSubmitting = false;
    bool submissionSent = false;
    bool isRecording = false;

    final recorder = AudioRecorder();

    String? inferMimeType(String? extension) {
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<bool> stopRecordingIfActive() async {
                if (!await recorder.isRecording()) {
                  return true;
                }
                final path = await recorder.stop();
                if (path == null) {
                  setSheetState(() {
                    isRecording = false;
                    errorText = 'Recording failed. Please try again.';
                  });
                  return false;
                }
                try {
                  final file = io.File(path);
                  final bytes = await file.readAsBytes();
                  try {
                    await file.delete();
                  } catch (_) {}
                  final now = DateTime.now();
                  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
                  final minute = now.minute.toString().padLeft(2, '0');
                  final period = now.hour >= 12 ? 'PM' : 'AM';
                  final recordedLabel = 'Recorded clip • $hour:$minute $period';
                  setSheetState(() {
                    audioBase64 = base64Encode(bytes);
                    audioMimeType = 'audio/aac';
                    audioLabel = recordedLabel;
                    isRecording = false;
                    errorText = null;
                  });
                  return true;
                } catch (_) {
                  setSheetState(() {
                    isRecording = false;
                    errorText = 'Unable to save recording.';
                  });
                  return false;
                }
              }

              Future<void> toggleRecording() async {
                if (isRecording) {
                  await stopRecordingIfActive();
                  return;
                }
                if (kIsWeb) {
                  setSheetState(() {
                    errorText = 'Recording is not supported in the browser.';
                  });
                  return;
                }
                if (!await recorder.hasPermission()) {
                  setSheetState(() {
                    errorText = 'Microphone permission denied.';
                  });
                  return;
                }
                try {
                  final tempPath =
                      '${io.Directory.systemTemp.path}${io.Platform.pathSeparator}learn_contribution_${DateTime.now().millisecondsSinceEpoch}.m4a';
                  await recorder.start(
                    const RecordConfig(
                      encoder: AudioEncoder.aacLc,
                      bitRate: 128000,
                      sampleRate: 44100,
                    ),
                    path: tempPath,
                  );
                  setSheetState(() {
                    isRecording = true;
                    errorText = null;
                    audioBase64 = null;
                    audioMimeType = null;
                    audioLabel = null;
                  });
                } catch (_) {
                  setSheetState(() {
                    errorText = 'Failed to start recording.';
                    isRecording = false;
                  });
                }
              }

              Future<void> pickAudio() async {
                if (isRecording) {
                  final finished = await stopRecordingIfActive();
                  if (!finished) {
                    return;
                  }
                }
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  withData: true,
                  allowedExtensions:
                      const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
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
                  setSheetState(() {
                    errorText = 'Unable to read audio file.';
                  });
                  return;
                }
                setSheetState(() {
                  audioBase64 = base64Encode(bytes);
                  audioMimeType = inferMimeType(file.extension);
                  audioLabel = file.name;
                  errorText = null;
                });
              }

              Future<void> submit() async {
                final navigator = Navigator.of(sheetContext);
                final term = termController.text.trim();
                final translation = translationController.text.trim();
                final partOfSpeech = partOfSpeechController.text.trim();
                final example = exampleController.text.trim();

                if (term.isEmpty || translation.isEmpty) {
                  setSheetState(() {
                    errorText = 'Provide both the word and its translation.';
                  });
                  return;
                }

                if (isRecording) {
                  final finished = await stopRecordingIfActive();
                  if (!finished) {
                    return;
                  }
                }

                setSheetState(() {
                  errorText = null;
                  isSubmitting = true;
                });

                final translations = <String, String>{
                  selectedTarget: translation,
                };

                final submission = await _learnStore.addContributorSubmission(
                  profile: profile,
                  term: term,
                  sourceLanguage: selectedSource,
                  translations: translations,
                  partOfSpeech: partOfSpeech.isEmpty ? null : partOfSpeech,
                  example: example.isEmpty ? null : example,
                  audioBase64: audioBase64,
                  audioMimeType: audioMimeType,
                );

                if (submission == null) {
                  setSheetState(() {
                    isSubmitting = false;
                    errorText =
                        'Contributor access is no longer active. Please contact support.';
                  });
                  return;
                }

                submissionSent = true;
                if (navigator.mounted) {
                  navigator.pop();
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Share a new word',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'We send every submission to admins for approval before it appears in Translate.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('contrib-source-$selectedSource'),
                            initialValue: selectedSource,
                            dropdownColor: const Color(0xFF0A1628),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Source language',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            items: availableLanguages
                                .map((lang) => DropdownMenuItem(
                                      value: lang,
                                      child: Text(lang),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() {
                                selectedSource = value;
                                targetOptions = availableLanguages
                                    .where((lang) => lang != selectedSource)
                                    .toList();
                                if (targetOptions.isEmpty) {
                                  targetOptions = selectedSource == 'English'
                                      ? <String>['Kibembe']
                                      : <String>['English'];
                                }
                                if (!targetOptions.contains(selectedTarget)) {
                                  selectedTarget = targetOptions.first;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('contrib-target-$selectedTarget'),
                            initialValue: selectedTarget,
                            dropdownColor: const Color(0xFF0A1628),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Translate to',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                            items: targetOptions
                                .map((lang) => DropdownMenuItem(
                                      value: lang,
                                      child: Text(lang),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() {
                                selectedTarget = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: termController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Word in $selectedSource',
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: translationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Translation in $selectedTarget',
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: partOfSpeechController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Part of speech (optional)',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: exampleController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Example sentence (optional)',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isSubmitting ? null : pickAudio,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB300),
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.file_upload),
                          label: Text(audioLabel == null
                              ? 'Attach voice note'
                              : 'Replace audio'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: isSubmitting ? null : toggleRecording,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isRecording
                                ? const Color(0xFFEF5350)
                                : Colors.white,
                            side: BorderSide(
                              color: isRecording
                                  ? const Color(0xFFEF5350)
                                  : Colors.white30,
                            ),
                          ),
                          icon: Icon(isRecording ? Icons.stop : Icons.mic),
                          label: Text(isRecording
                              ? 'Stop recording'
                              : 'Record voice note'),
                        ),
                      ],
                    ),
                    if (isRecording) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.fiber_manual_record,
                              color: Color(0xFFEF5350), size: 14),
                          SizedBox(width: 8),
                          Text(
                            'Listening… tap stop when you are done.',
                            style: TextStyle(
                                color: Color(0xFFEF5350), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (audioLabel != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              audioLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setSheetState(() {
                                      audioBase64 = null;
                                      audioMimeType = null;
                                      audioLabel = null;
                                    });
                                  },
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                            color: Color(0xFFEF5350), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : submit,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                            isSubmitting ? 'Submitting…' : 'Send for review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}

    termController.dispose();
    translationController.dispose();
    partOfSpeechController.dispose();
    exampleController.dispose();

    if (submissionSent && mounted) {
      _syncFromStore();
      _showProfileSnack(
        'Submission sent for admin review.',
        color: const Color(0xFF00BFA5),
      );
    }
  }

  void _showProfileSnack(String message, {Color color = const Color(0xFF26C6DA)}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00BFA5)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.white.withAlpha(180))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfile() async {
    final controller = TextEditingController(text: _userName);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Your Name',
            labelStyle: TextStyle(color: Colors.white54),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00BFA5))),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  _userName = trimmed;
                }
                _updateUserLeaderboardName(_userName);
              });
              _saveProfile();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFunds() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Funds', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            labelStyle: TextStyle(color: Colors.white54),
            prefixText: '₦₲ ',
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00BFA5))),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) {
                return;
              }
              setState(() {
                _balance += amount;
              });
              _walletStore.adjustBalance(amount);
              _saveProfile();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
          content: Text(
            'Added ₦₲ ${amount.toStringAsFixed(2)} to your balance!'),
                  backgroundColor: const Color(0xFF00BFA5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.black),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F3A).withAlpha(230),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.translate, 'Translate', 1),
              _buildNavItem(Icons.extension, 'Games', 2),
              _buildNavItem(Icons.leaderboard, 'Ranking', 3),
              _buildNavItem(Icons.person, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? const Color(0xFF00BFA5) : Colors.white54,
              size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF00BFA5) : Colors.white54,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
