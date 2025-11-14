import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learn_models.dart';

class LearnDataStore extends ChangeNotifier {
  static final LearnDataStore _instance = LearnDataStore._internal();
  static LearnDataStore get instance => _instance;

  LearnDataStore._internal();

  List<QuizEvent> _events = [];
  List<QuizCategory> _categories = [];
  List<ContentArticle> _articles = [];
  Map<String, bool> _translatorLanguages = {};
  List<TranslatorDictionaryEntry> _translatorEntries = [];
  List<TranslatorQuickPhrase> _translatorQuickPhrases = [];
  List<TranslatorContributorProfile> _contributorProfiles = [];
  List<TranslatorContributorSubmission> _contributorSubmissions = [];
  List<TranslatorWordGame> _wordGames = [];

  List<QuizEvent> get events => _events;
  List<QuizCategory> get categories => _categories;
  List<ContentArticle> get articles => _articles;
  Map<String, bool> get translatorLanguages => Map.unmodifiable(_translatorLanguages);
  List<String> get enabledTranslatorLanguages => _translatorLanguages.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();
  List<TranslatorDictionaryEntry> get translatorEntries => List.unmodifiable(_translatorEntries);
  List<TranslatorQuickPhrase> get quickPhrases => List.unmodifiable(_translatorQuickPhrases);
  List<TranslatorContributorProfile> get contributorProfiles =>
      List.unmodifiable(_contributorProfiles);
  List<TranslatorContributorSubmission> get contributorSubmissions =>
      List.unmodifiable(_contributorSubmissions);
  List<TranslatorWordGame> get wordGames => List.unmodifiable(_wordGames);

  List<TranslatorDictionaryEntry> entriesForLanguage(String language) {
    final normalized = language.toLowerCase();
    return _translatorEntries.where((entry) {
      if (entry.sourceLanguage.toLowerCase() == normalized) {
        return true;
      }
      return entry.translations.keys
          .any((lang) => lang.toLowerCase() == normalized);
    }).toList();
  }

  TranslatorContributorProfile? profileForUser(String userId) {
    try {
      return _contributorProfiles.firstWhere((profile) => profile.userId == userId);
    } catch (_) {
      return null;
    }
  }

  List<TranslatorContributorSubmission> submissionsForContributor(String contributorId) {
    return _contributorSubmissions
        .where((submission) => submission.contributorId == contributorId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }
  
  List<ContentArticle> getArticlesByCategory(String category) {
    return _articles.where((a) => a.category == category && a.status == 'approved').toList();
  }
  
  List<ContentArticle> getPendingArticles() {
    return _articles.where((a) => a.status == 'pending').toList();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load events
    final eventsJson = prefs.getString('learn_events');
    if (eventsJson != null) {
      final List<dynamic> decoded = jsonDecode(eventsJson);
      _events = decoded.map((e) => QuizEvent.fromJson(e)).toList();
    } else {
      _initializeDefaultEvents();
      await saveEvents();
    }
    final eventsUpgraded = _upgradeLegacyEvents();
    if (eventsUpgraded) {
      await saveEvents();
    }
    
    // Load categories
    final categoriesJson = prefs.getString('learn_categories');
    if (categoriesJson != null) {
      final List<dynamic> decoded = jsonDecode(categoriesJson);
      _categories = decoded.map((e) => QuizCategory.fromJson(e)).toList();
    } else {
      _initializeDefaultCategories();
      await saveCategories();
    }
    final categoriesUpgraded = _upgradeLegacyCategories();
    if (categoriesUpgraded) {
      await saveCategories();
    }
    
    // Load articles
    final articlesJson = prefs.getString('learn_articles');
    if (articlesJson != null) {
      final List<dynamic> decoded = jsonDecode(articlesJson);
      _articles = decoded.map((e) => ContentArticle.fromJson(e)).toList();
    }

    // Load translator language toggles
    final translatorJson = prefs.getString('learn_translator_languages');
    if (translatorJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(translatorJson);
      _translatorLanguages = decoded.map(
        (key, value) => MapEntry(key, value is bool ? value : value == true),
      );
    } else {
      _translatorLanguages = _defaultTranslatorLanguages();
      await _saveTranslatorLanguages(prefs: prefs);
    }

    // Ensure defaults exist for any new languages
    final defaults = _defaultTranslatorLanguages();
    bool updated = false;
    for (final entry in defaults.entries) {
      if (!_translatorLanguages.containsKey(entry.key)) {
        _translatorLanguages[entry.key] = entry.value;
        updated = true;
      }
    }
    if (updated) {
      await _saveTranslatorLanguages(prefs: prefs);
    }

    // Load translator dictionary entries
    final dictionaryJson = prefs.getString('learn_translator_entries');
    if (dictionaryJson != null) {
      final List<dynamic> decoded = jsonDecode(dictionaryJson);
      _translatorEntries =
          decoded.map((entry) => TranslatorDictionaryEntry.fromJson(entry)).toList();
    } else {
      _translatorEntries = _buildDefaultTranslatorEntries();
      await _saveTranslatorEntries(prefs: prefs);
    }

    final quickPhrasesJson = prefs.getString('learn_translator_quick_phrases');
    if (quickPhrasesJson != null) {
      final List<dynamic> decoded = jsonDecode(quickPhrasesJson);
      _translatorQuickPhrases =
          decoded.map((entry) => TranslatorQuickPhrase.fromJson(entry)).toList();
    } else {
      _translatorQuickPhrases = _buildDefaultQuickPhrases();
      await _saveQuickPhrases(prefs: prefs);
    }

    final wordGamesJson = prefs.getString('learn_word_games');
    if (wordGamesJson != null) {
      final List<dynamic> decoded = jsonDecode(wordGamesJson);
      _wordGames =
          decoded.map((entry) => TranslatorWordGame.fromJson(entry)).toList();
    } else {
      _wordGames = _buildDefaultWordGames();
      await _saveWordGames(prefs: prefs);
    }

    final wordGamesUpdated = _upgradeWordGames();
    if (wordGamesUpdated) {
      await _saveWordGames(prefs: prefs);
    }

    final contributorProfilesJson = prefs.getString('learn_contributor_profiles');
    if (contributorProfilesJson != null) {
      final List<dynamic> decoded = jsonDecode(contributorProfilesJson);
      _contributorProfiles =
          decoded.map((entry) => TranslatorContributorProfile.fromJson(entry)).toList();
    }

    final contributorSubmissionsJson =
        prefs.getString('learn_contributor_submissions');
    if (contributorSubmissionsJson != null) {
      final List<dynamic> decoded = jsonDecode(contributorSubmissionsJson);
      _contributorSubmissions =
          decoded.map((entry) => TranslatorContributorSubmission.fromJson(entry)).toList();
    }
    
    notifyListeners();
  }

  void _initializeDefaultEvents() {
    final now = DateTime.now();
    _events = [
      QuizEvent(
        id: '1',
        title: 'Football Quiz Arena',
        subtitle: 'European club legends and World Cup trivia',
        date: DateTime(2025, 4, 7, 17, 0),
        participants: 1292,
        maxParticipants: 10000,
        prize: 1300.0,
        entryFee: 50.0,
        icon: Icons.sports_soccer,
        color: const Color(0xFF00BFA5),
        categories: ['Football Quiz', 'Upcoming', 'Featured'],
        thumbnailUrl: 'assets/images/default_promo.png',
      ),
      QuizEvent(
        id: '2',
        title: 'Geography Quiz Rally',
        subtitle: 'Capitals, landforms, and world wonders',
        date: now.add(const Duration(hours: 1)),
        participants: 856,
        maxParticipants: 5000,
        prize: 1200.0,
        entryFee: 50.0,
        icon: Icons.public,
        color: const Color(0xFF00BFA5),
        categories: ['Geography Quiz', 'Upcoming'],
        thumbnailUrl: 'assets/images/default_promo.png',
      ),
      QuizEvent(
        id: '3',
        title: 'Politics Quiz Briefing',
        subtitle: 'Global policy, elections, and civic trivia',
        date: now.add(const Duration(hours: 2)),
        participants: 543,
        maxParticipants: 3000,
        prize: 800.0,
        entryFee: 100.0,
        icon: Icons.account_balance,
        color: const Color(0xFF7E57C2),
        categories: ['Politics Quiz', 'Upcoming'],
        thumbnailUrl: 'assets/images/default_promo.png',
      ),
      QuizEvent(
        id: '4',
        title: 'General Quiz Showdown',
        subtitle: 'Rapid-fire general knowledge sprint',
        date: now.add(const Duration(hours: 1)),
        participants: 1024,
        maxParticipants: 8000,
        prize: 2200.0,
        entryFee: 100.0,
        icon: Icons.quiz,
        color: const Color(0xFF5C6BC0),
        categories: ['General Quiz', 'Upcoming', 'Highest Prize'],
        thumbnailUrl: 'assets/images/default_promo.png',
      ),
      QuizEvent(
        id: '5',
        title: 'Map Quiz Expedition',
        subtitle: 'Pinpoint countries, regions, and borders in seconds',
        date: now.add(const Duration(hours: 3)),
        participants: 412,
        maxParticipants: 4000,
        prize: 950.0,
        entryFee: 75.0,
        icon: Icons.map,
        color: const Color(0xFF26C6DA),
        categories: ['Map Quiz', 'Upcoming'],
        thumbnailUrl: 'assets/images/default_promo.png',
      ),
    ];
  }

  void _initializeDefaultCategories() {
    _categories = _buildModernDefaultCategories();
  }

  Map<String, bool> _defaultTranslatorLanguages() {
    return {
      'Kibembe': false,
      'English': true,
      'Spanish': true,
      'French': true,
      'German': true,
      'Yoruba': true,
      'Igbo': true,
    };
  }

  List<QuizCategory> _buildModernDefaultCategories() {
    return [
      QuizCategory(id: 'quiz-football', name: 'Football Quiz', icon: Icons.sports_soccer),
      QuizCategory(id: 'quiz-geography', name: 'Geography Quiz', icon: Icons.public),
      QuizCategory(id: 'quiz-politics', name: 'Politics Quiz', icon: Icons.gavel),
      QuizCategory(id: 'quiz-general', name: 'General Quiz', icon: Icons.quiz),
      QuizCategory(id: 'quiz-map', name: 'Map Quiz', icon: Icons.map),
    ];
  }

  bool _upgradeLegacyEvents() {
    bool updated = false;
    for (final event in _events) {
      if (event.categories.contains('Football Quiz') || event.categories.contains('Geography Quiz')) {
        continue;
      }

      switch (event.title) {
        case 'Football':
          event.title = 'Football Quiz Arena';
          event.subtitle = 'European club legends and World Cup trivia';
          event.categories = ['Football Quiz', 'Upcoming', 'Featured'];
          event.icon = Icons.sports_soccer;
          updated = true;
          break;
        case 'Geography':
          event.title = 'Geography Quiz Rally';
          event.subtitle = 'Capitals, landforms, and world wonders';
          event.categories = ['Geography Quiz', 'Upcoming'];
          event.icon = Icons.public;
          updated = true;
          break;
        case 'Politics':
          event.title = 'Politics Quiz Briefing';
          event.subtitle = 'Global policy, elections, and civic trivia';
          event.categories = ['Politics Quiz', 'Upcoming'];
          event.icon = Icons.account_balance;
          updated = true;
          break;
        case 'General':
          event.title = 'General Quiz Showdown';
          event.subtitle = 'Rapid-fire general knowledge sprint';
          event.categories = ['General Quiz', 'Upcoming', 'Highest Prize'];
          event.icon = Icons.quiz;
          updated = true;
          break;
        default:
          if (!event.categories.any((c) => c.endsWith('Quiz'))) {
            event.categories = [...event.categories, 'Featured'];
            updated = true;
          }
      }
    }
    return updated;
  }

  bool _upgradeLegacyCategories() {
    const legacyNames = {'Books', 'Sports', 'Science', 'History', 'Trivia'};
    if (_categories.isEmpty) {
      _categories = _buildModernDefaultCategories();
      return true;
    }

    final legacyOnly = _categories.every((c) => legacyNames.contains(c.name));
    if (legacyOnly) {
      _categories = _buildModernDefaultCategories();
      return true;
    }

    return false;
  }

  bool _upgradeWordGames() {
    bool updated = false;
    for (final game in _wordGames) {
      if (game.gameStyle.trim().isEmpty) {
        game.gameStyle = 'scramble';
        updated = true;
      }
      final hasLegacyPrompts = game.prompts.isNotEmpty &&
          game.prompts.every((prompt) =>
              prompt.type == 'translation' || prompt.type == 'sentence');
      if (hasLegacyPrompts && game.isActive) {
        game.isActive = false;
        updated = true;
      }
    }

    final defaults = _buildDefaultWordGames();
    final existingIds = _wordGames.map((game) => game.id).toSet();
    for (final defaultGame in defaults) {
      if (!existingIds.contains(defaultGame.id)) {
        _wordGames.add(defaultGame);
        updated = true;
      }
    }

    return updated;
  }

  Future<void> _saveTranslatorLanguages({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_translatorLanguages);
    await targetPrefs.setString('learn_translator_languages', encoded);
    notifyListeners();
  }

  Future<void> setTranslatorLanguageEnabled(String language, bool enabled) async {
    _translatorLanguages[language] = enabled;
    await _saveTranslatorLanguages();
  }

  Future<void> _saveTranslatorEntries({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_translatorEntries.map((e) => e.toJson()).toList());
    await targetPrefs.setString('learn_translator_entries', encoded);
    notifyListeners();
  }

  Future<void> _saveQuickPhrases({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_translatorQuickPhrases.map((e) => e.toJson()).toList());
    await targetPrefs.setString('learn_translator_quick_phrases', encoded);
    notifyListeners();
  }

  Future<void> _saveContributorProfiles({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_contributorProfiles.map((e) => e.toJson()).toList());
    await targetPrefs.setString('learn_contributor_profiles', encoded);
    notifyListeners();
  }

  Future<void> _saveContributorSubmissions({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_contributorSubmissions.map((e) => e.toJson()).toList());
    await targetPrefs.setString('learn_contributor_submissions', encoded);
    notifyListeners();
  }

  Future<void> _saveWordGames({SharedPreferences? prefs}) async {
    final targetPrefs = prefs ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode(_wordGames.map((game) => game.toJson()).toList());
    await targetPrefs.setString('learn_word_games', encoded);
    notifyListeners();
  }

  List<TranslatorDictionaryEntry> searchDictionary(
    String query, {
    String? sourceLanguage,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return [];
    }

    final normalizedLanguage = sourceLanguage?.toLowerCase();

    return _translatorEntries.where((entry) {
      final matchesLanguage = normalizedLanguage == null
          ? true
          : entry.sourceLanguage.toLowerCase() == normalizedLanguage ||
              entry.translations.keys.any((lang) => lang.toLowerCase() == normalizedLanguage);
      if (!matchesLanguage) return false;

      final termMatches = entry.term.toLowerCase().contains(normalizedQuery);
      final translationMatch = entry.translations.values.any(
        (value) => value.toLowerCase().contains(normalizedQuery),
      );
      return termMatches || translationMatch;
    }).toList();
  }

  TranslatorDictionaryEntry? findDictionaryEntry(String term, {String? sourceLanguage}) {
    final normalizedTerm = term.trim().toLowerCase();
    final normalizedLanguage = sourceLanguage?.toLowerCase();

    for (final entry in _translatorEntries) {
      final languageApplies = normalizedLanguage == null
          ? true
          : entry.sourceLanguage.toLowerCase() == normalizedLanguage ||
              entry.translations.keys.any((lang) => lang.toLowerCase() == normalizedLanguage);
      if (!languageApplies) {
        continue;
      }

      final entryTerm = entry.term.trim().toLowerCase();
      if (normalizedLanguage == null) {
        if (entryTerm == normalizedTerm ||
            entry.translations.values.any((value) => value.trim().toLowerCase() == normalizedTerm)) {
          return entry;
        }
        continue;
      }

      if (entry.sourceLanguage.toLowerCase() == normalizedLanguage && entryTerm == normalizedTerm) {
        return entry;
      }

      String? translationValue;
      for (final translation in entry.translations.entries) {
        if (translation.key.toLowerCase() == normalizedLanguage) {
          translationValue = translation.value;
          break;
        }
      }
      if (translationValue != null && translationValue.trim().toLowerCase() == normalizedTerm) {
        return entry;
      }
    }
    return null;
  }

  Future<void> addTranslatorEntry(TranslatorDictionaryEntry entry) async {
    _translatorEntries.add(entry);
    await _saveTranslatorEntries();
  }

  Future<void> updateTranslatorEntry(TranslatorDictionaryEntry entry) async {
    final index = _translatorEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _translatorEntries[index] = entry;
      await _saveTranslatorEntries();
    }
  }

  Future<TranslatorContributorProfile> submitContributorRequest({
    required String userId,
    required String displayName,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final existingIndex =
        _contributorProfiles.indexWhere((profile) => profile.userId == userId);

    TranslatorContributorProfile profile;
    if (existingIndex != -1) {
      profile = _contributorProfiles[existingIndex];
      profile.displayName = displayName;
      profile.status = 'pending';
      profile.requestedAt = now;
      profile.reviewedAt = null;
      profile.reviewer = null;
      profile.rejectionReason = null;
      profile.applicationNote = note;
      _contributorProfiles[existingIndex] = profile;
    } else {
      profile = TranslatorContributorProfile(
        id: 'contributor-${now.millisecondsSinceEpoch}',
        userId: userId,
        displayName: displayName,
        status: 'pending',
        requestedAt: now,
        applicationNote: note,
      );
      _contributorProfiles.add(profile);
    }

    await _saveContributorProfiles(prefs: prefs);
    return profile;
  }

  Future<void> updateContributorStatus({
    required String profileId,
    required String status,
    String? reviewer,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _contributorProfiles.indexWhere((p) => p.id == profileId);
    if (index == -1) {
      return;
    }

    final profile = _contributorProfiles[index];
    profile.status = status;
    profile.reviewedAt = DateTime.now();
    profile.reviewer = reviewer;
    profile.rejectionReason = status == 'rejected' ? note : null;
    _contributorProfiles[index] = profile;

    await _saveContributorProfiles(prefs: prefs);
  }

  Future<TranslatorContributorSubmission?> addContributorSubmission({
    required TranslatorContributorProfile profile,
    required String term,
    required String sourceLanguage,
    required Map<String, String> translations,
    String? partOfSpeech,
    String? example,
    String? audioBase64,
    String? audioMimeType,
  }) async {
    if (!profile.isApproved) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final submission = TranslatorContributorSubmission(
      id: 'submission-${DateTime.now().millisecondsSinceEpoch}',
      contributorId: profile.id,
      contributorName: profile.displayName,
      sourceLanguage: sourceLanguage,
      term: term,
      translations: translations,
      partOfSpeech: partOfSpeech,
      example: example,
      audioBase64: audioBase64,
      audioMimeType: audioMimeType,
      status: 'pending',
    );
    _contributorSubmissions.add(submission);
    await _saveContributorSubmissions(prefs: prefs);
    return submission;
  }

  Future<void> decideOnContributorSubmission({
    required String submissionId,
    required String status,
    String? reviewer,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index =
        _contributorSubmissions.indexWhere((entry) => entry.id == submissionId);
    if (index == -1) {
      return;
    }

    final submission = _contributorSubmissions[index];
    submission.status = status;
    submission.reviewer = reviewer;
    submission.reviewNote = note;
    submission.decidedAt = DateTime.now();
    _contributorSubmissions[index] = submission;

    if (status == 'approved') {
      final entry = TranslatorDictionaryEntry(
        id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
        sourceLanguage: submission.sourceLanguage,
        term: submission.term,
        translations: Map<String, String>.from(submission.translations),
        partOfSpeech: submission.partOfSpeech,
        example: submission.example,
        audioBase64: submission.audioBase64,
        audioMimeType: submission.audioMimeType,
      );
      await addTranslatorEntry(entry);

      final profileIndex =
          _contributorProfiles.indexWhere((p) => p.id == submission.contributorId);
      if (profileIndex != -1) {
        final profile = _contributorProfiles[profileIndex];
        profile.approvedCount = (profile.approvedCount + 1);
        _contributorProfiles[profileIndex] = profile;
        await _saveContributorProfiles(prefs: prefs);
      }
    }

    await _saveContributorSubmissions(prefs: prefs);
  }

  Future<void> addWordGame(TranslatorWordGame game) async {
    _wordGames.add(game);
    await _saveWordGames();
  }

  Future<void> updateWordGameDetails({
    required String gameId,
    String? title,
    String? description,
    bool? isActive,
    String? gameStyle,
  }) async {
    final index = _wordGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }
    final game = _wordGames[index];
    if (title != null) {
      game.title = title;
    }
    if (description != null) {
      game.description = description;
    }
    if (isActive != null) {
      game.isActive = isActive;
    }
    if (gameStyle != null && gameStyle.trim().isNotEmpty) {
      game.gameStyle = gameStyle;
    }
    _wordGames[index] = game;
    await _saveWordGames();
  }

  Future<void> deleteWordGame(String gameId) async {
    _wordGames.removeWhere((game) => game.id == gameId);
    await _saveWordGames();
  }

  Future<void> addPromptToGame({
    required String gameId,
    required TranslatorWordGamePrompt prompt,
  }) async {
    final index = _wordGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }
    final game = _wordGames[index];
    game.prompts.add(prompt);
    _wordGames[index] = game;
    await _saveWordGames();
  }

  Future<void> updatePromptInGame({
    required String gameId,
    required TranslatorWordGamePrompt prompt,
  }) async {
    final index = _wordGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }
    final game = _wordGames[index];
    final promptIndex =
        game.prompts.indexWhere((existing) => existing.id == prompt.id);
    if (promptIndex == -1) {
      return;
    }
    game.prompts[promptIndex] = prompt
      ..updatedAt = DateTime.now();
    _wordGames[index] = game;
    await _saveWordGames();
  }

  Future<void> removePromptFromGame({
    required String gameId,
    required String promptId,
  }) async {
    final index = _wordGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }
    final game = _wordGames[index];
    game.prompts.removeWhere((prompt) => prompt.id == promptId);
    _wordGames[index] = game;
    await _saveWordGames();
  }

  Future<void> recordWordGameResult({
    required String gameId,
    required int score,
    required int total,
  }) async {
    final index = _wordGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }
    final game = _wordGames[index];
    game.playCount = (game.playCount + 1);
    game.lastPlayedAt = DateTime.now();
    if (total > 0 && score >= 0) {
      if (score > game.bestScore || total > game.bestOutOf) {
        game.bestScore = score;
        game.bestOutOf = total;
      } else if (score == game.bestScore && total > game.bestOutOf) {
        game.bestOutOf = total;
      }
    }
    _wordGames[index] = game;
    await _saveWordGames();
  }

  Future<void> deleteTranslatorEntry(String id) async {
    _translatorEntries.removeWhere((entry) => entry.id == id);
    await _saveTranslatorEntries();
  }

  Future<void> addQuickPhrase(TranslatorQuickPhrase phrase) async {
    _translatorQuickPhrases.add(phrase);
    await _saveQuickPhrases();
  }

  Future<void> updateQuickPhrase(TranslatorQuickPhrase phrase) async {
    final index = _translatorQuickPhrases.indexWhere((e) => e.id == phrase.id);
    if (index != -1) {
      _translatorQuickPhrases[index] = phrase;
      await _saveQuickPhrases();
    }
  }

  Future<void> deleteQuickPhrase(String id) async {
    _translatorQuickPhrases.removeWhere((phrase) => phrase.id == id);
    await _saveQuickPhrases();
  }

  Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString('learn_events', encoded);
    notifyListeners();
  }

  Future<void> saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_categories.map((e) => e.toJson()).toList());
    await prefs.setString('learn_categories', encoded);
    notifyListeners();
  }

  Future<void> addEvent(QuizEvent event) async {
    _events.add(event);
    await saveEvents();
  }

  Future<void> updateEvent(QuizEvent event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      await saveEvents();
    }
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await saveEvents();
  }

  Future<void> addCategory(QuizCategory category) async {
    _categories.add(category);
    await saveCategories();
  }

  Future<void> updateCategory(QuizCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      await saveCategories();
    }
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    await saveCategories();
  }

  List<TranslatorDictionaryEntry> _buildDefaultTranslatorEntries() {
    final seedPhrases = <String, Map<String, String>>{
      'hello': {
        'English': 'Hello',
        'Spanish': 'Hola',
        'French': 'Bonjour',
        'German': 'Hallo',
        'Yoruba': 'Pẹlẹ o',
        'Igbo': 'Ndewo',
        'Kibembe': 'Mbote',
      },
      'good morning': {
        'English': 'Good morning',
        'Spanish': 'Buenos días',
        'French': 'Bonjour',
        'German': 'Guten Morgen',
        'Yoruba': 'Ẹ káàárọ̀',
        'Igbo': 'Ụtụtụ ọma',
        'Kibembe': 'Mbote ya tongo',
      },
      'thank you': {
        'English': 'Thank you',
        'Spanish': 'Gracias',
        'French': 'Merci',
        'German': 'Danke',
        'Yoruba': 'Ẹ ṣé',
        'Igbo': 'Imela',
        'Kibembe': 'Matondo',
      },
      'good luck': {
        'English': 'Good luck',
        'Spanish': 'Buena suerte',
        'French': 'Bonne chance',
        'German': 'Viel Glück',
        'Yoruba': 'Orire',
        'Igbo': 'Ụsọ ọma',
        'Kibembe': 'Bolamu',
      },
      'welcome everyone': {
        'English': 'Welcome everyone',
        'Spanish': 'Bienvenidos todos',
        'French': 'Bienvenue à tous',
        'German': 'Willkommen alle',
        'Yoruba': 'Ẹ kú abọ̀ gbogbo yín',
        'Igbo': 'Nnọọ unu niile',
        'Kibembe': 'Mbote beno nyonso',
      },
    };

    final entries = <TranslatorDictionaryEntry>[];
    for (final seed in seedPhrases.entries) {
      final term = seed.key;
      final translations = seed.value;
      entries.add(
        TranslatorDictionaryEntry(
          id: 'seed-en-${term.replaceAll(' ', '-')}',
          sourceLanguage: 'English',
          term: _beautifyPhrase(term),
          translations: translations,
          partOfSpeech: 'phrase',
        ),
      );

      final kibembe = translations['Kibembe'];
      if (kibembe != null && kibembe.isNotEmpty) {
        entries.add(
          TranslatorDictionaryEntry(
            id: 'seed-kb-${term.replaceAll(' ', '-')}',
            sourceLanguage: 'Kibembe',
            term: kibembe,
            translations: {
              'English': translations['English'] ?? _beautifyPhrase(term),
            },
            partOfSpeech: 'phrase',
          ),
        );
      }
    }
    return entries;
  }

  List<TranslatorQuickPhrase> _buildDefaultQuickPhrases() {
    return [
      TranslatorQuickPhrase(
        id: 'qp_welcome',
        label: 'Welcome players',
        translations: {
          'English': 'Welcome to the quiz everyone!',
          'Kibembe': 'Mbote na bino nyonso na quiz!',
        },
      ),
      TranslatorQuickPhrase(
        id: 'qp_energy',
        label: 'Keep the energy high',
        translations: {
          'English': 'Keep the energy high!',
          'Kibembe': 'Bokoba na makasi!',
        },
      ),
      TranslatorQuickPhrase(
        id: 'qp_final_round',
        label: 'Final round starts',
        translations: {
          'English': 'Final round starts now!',
          'Kibembe': 'Ronde ya suka ebandi sikoyo!',
        },
      ),
      TranslatorQuickPhrase(
        id: 'qp_congrats',
        label: 'Congratulations winner',
        translations: {
          'English': 'Congratulations to our winner!',
          'Kibembe': 'Bomoyi malamu na moyangeli!',
        },
      ),
    ];
  }

  List<TranslatorWordGame> _buildDefaultWordGames() {
    return [
      TranslatorWordGame(
        id: 'wg_scramble_intro',
        title: 'Word Scramble Warm-up',
        description: 'Unscramble popular words drawn from the Translate library.',
        prompts: [
          TranslatorWordGamePrompt(
            id: 'wg_scramble_intro_1',
            type: 'scramble',
            term: 'Mbote',
            translation: 'Hello',
            hint: 'Bembe greeting for hello',
            alternateAnswers: const ['Hello', 'Hi'],
          ),
          TranslatorWordGamePrompt(
            id: 'wg_scramble_intro_2',
            type: 'scramble',
            term: 'Victory',
            translation: 'Victory',
            hint: 'What every team plays for',
          ),
          TranslatorWordGamePrompt(
            id: 'wg_scramble_intro_3',
            type: 'scramble',
            term: 'Alliance',
            translation: 'Alliance',
            hint: 'When people unite for a cause',
          ),
        ],
      ),
      TranslatorWordGame(
        id: 'wg_translation_drill',
        title: 'Speed Translation Drill',
        description: 'Type the matching translation before the timer runs out.',
        prompts: [
          TranslatorWordGamePrompt(
            id: 'wg_translation_drill_1',
            type: 'translation',
            term: 'Mbote',
            translation: 'Hello',
            hint: 'Greeting in Kibembe',
            alternateAnswers: const ['Hi'],
          ),
          TranslatorWordGamePrompt(
            id: 'wg_translation_drill_2',
            type: 'translation',
            term: 'Team spirit',
            translation: 'Esprit d\'équipe',
            hint: 'French version of team spirit',
            alternateAnswers: const ['Esprit dequipe', "Esprit d'equipe"],
          ),
          TranslatorWordGamePrompt(
            id: 'wg_translation_drill_3',
            type: 'translation',
            term: 'Courage',
            translation: 'Courage',
            hint: 'Same word in English and French',
          ),
        ],
      ),
      TranslatorWordGame(
        id: 'wg_sentence_builder',
        title: 'Sentence Builder',
        description: 'Fill in the missing word to complete the sentence.',
        prompts: [
          TranslatorWordGamePrompt(
            id: 'wg_sentence_builder_1',
            type: 'sentence',
            term: 'victory',
            translation: 'victory',
            sentenceTemplate: 'The coach promised ___ if we train together.',
            hint: 'It is the reason we train',
          ),
          TranslatorWordGamePrompt(
            id: 'wg_sentence_builder_2',
            type: 'sentence',
            term: 'alliance',
            translation: 'alliance',
            sentenceTemplate: 'Our ___ with the neighbouring club makes us stronger.',
            hint: 'A pact between groups',
          ),
        ],
      ),
    ];
  }

  String _beautifyPhrase(String value) {
    final words = value.split(' ');
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}')
        .join(' ');
  }
  
  // Article management
  Future<void> saveArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_articles.map((e) => e.toJson()).toList());
    await prefs.setString('learn_articles', encoded);
    notifyListeners();
  }

  Future<void> addArticle(ContentArticle article) async {
    _articles.add(article);
    await saveArticles();
  }

  Future<void> updateArticle(ContentArticle article) async {
    final index = _articles.indexWhere((a) => a.id == article.id);
    if (index != -1) {
      _articles[index] = article;
      await saveArticles();
    }
  }

  Future<void> deleteArticle(String id) async {
    _articles.removeWhere((a) => a.id == id);
    await saveArticles();
  }
  
  Future<void> approveArticle(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index != -1) {
      _articles[index].status = 'approved';
      await saveArticles();
    }
  }
  
  Future<void> rejectArticle(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index != -1) {
      _articles[index].status = 'rejected';
      await saveArticles();
    }
  }
}
