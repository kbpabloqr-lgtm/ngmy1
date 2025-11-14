import 'package:flutter/material.dart';

class QuizQuestion {
  final String id;
  String question;
  List<String> options;
  int correctAnswerIndex;
  int points;
  int timeLimit; // in seconds

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.points = 10,
    this.timeLimit = 30,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correctAnswerIndex': correctAnswerIndex,
        'points': points,
        'timeLimit': timeLimit,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'],
        question: json['question'],
        options: List<String>.from(json['options']),
        correctAnswerIndex: json['correctAnswerIndex'],
        points: json['points'] ?? 10,
        timeLimit: json['timeLimit'] ?? 30,
      );
}

class QuizEvent {
  final String id;
  String title;
  String subtitle;
  DateTime date;
  int participants;
  int maxParticipants;
  double prize;
  double entryFee;
  IconData icon;
  Color color;
  List<String> categories;
  bool joined;
  bool isActive;
  List<QuizQuestion> questions;
  String? thumbnailUrl;
  String? preQuizVideoUrl;
  String? preQuizVideoTitle;

  QuizEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.participants,
    required this.maxParticipants,
    required this.prize,
    required this.entryFee,
    required this.icon,
    required this.color,
    required this.categories,
    this.joined = false,
    this.isActive = true,
    List<QuizQuestion>? questions,
    this.thumbnailUrl,
    this.preQuizVideoUrl,
    this.preQuizVideoTitle,
  }) : questions = questions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'date': date.toIso8601String(),
        'participants': participants,
        'maxParticipants': maxParticipants,
        'prize': prize,
        'entryFee': entryFee,
        'iconCodePoint': icon.codePoint,
        'colorValue': (color.a * 255).round() << 24 |
            (color.r * 255).round() << 16 |
            (color.g * 255).round() << 8 |
            (color.b * 255).round(),
        'categories': categories,
        'joined': joined,
        'isActive': isActive,
        'questions': questions.map((q) => q.toJson()).toList(),
        'thumbnailUrl': thumbnailUrl,
        'preQuizVideoUrl': preQuizVideoUrl,
        'preQuizVideoTitle': preQuizVideoTitle,
      };

  factory QuizEvent.fromJson(Map<String, dynamic> json) => QuizEvent(
        id: json['id'],
        title: json['title'],
        subtitle: json['subtitle'],
        date: DateTime.parse(json['date']),
        participants: json['participants'],
        maxParticipants: json['maxParticipants'],
        prize: json['prize'].toDouble(),
        entryFee: json['entryFee'].toDouble(),
        icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
        color: Color(json['colorValue']),
        categories: List<String>.from(json['categories']),
        joined: json['joined'] ?? false,
        isActive: json['isActive'] ?? true,
        questions: json['questions'] != null
            ? (json['questions'] as List)
                .map((q) => QuizQuestion.fromJson(q))
                .toList()
            : [],
        thumbnailUrl: json['thumbnailUrl'],
        preQuizVideoUrl: json['preQuizVideoUrl'],
        preQuizVideoTitle: json['preQuizVideoTitle'],
      );
}

class TranslatorDictionaryEntry {
  final String id;
  String sourceLanguage;
  String term;
  Map<String, String> translations; // target language -> definition/meaning
  String? partOfSpeech;
  String? example;
  String? audioBase64;
  String? audioMimeType;
  DateTime createdAt;

  TranslatorDictionaryEntry({
    required this.id,
    required this.sourceLanguage,
    required this.term,
    Map<String, String>? translations,
    this.partOfSpeech,
    this.example,
    this.audioBase64,
    this.audioMimeType,
    DateTime? createdAt,
  })  : translations = translations ?? <String, String>{},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceLanguage': sourceLanguage,
        'term': term,
        'translations': translations,
        'partOfSpeech': partOfSpeech,
        'example': example,
        'audioBase64': audioBase64,
        'audioMimeType': audioMimeType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TranslatorDictionaryEntry.fromJson(Map<String, dynamic> json) =>
      TranslatorDictionaryEntry(
        id: json['id'],
        sourceLanguage: json['sourceLanguage'],
        term: json['term'],
        translations: json['translations'] != null
            ? Map<String, String>.from(json['translations'])
            : <String, String>{},
        partOfSpeech: json['partOfSpeech'],
        example: json['example'],
        audioBase64: json['audioBase64'],
        audioMimeType: json['audioMimeType'],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class TranslatorQuickPhrase {
  final String id;
  String label;
  Map<String, String> translations;
  DateTime createdAt;
  String? audioBase64;
  String? audioMimeType;

  TranslatorQuickPhrase({
    required this.id,
    required this.label,
    Map<String, String>? translations,
    DateTime? createdAt,
    this.audioBase64,
    this.audioMimeType,
  })  : translations = translations ?? <String, String>{},
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'translations': translations,
        'audioBase64': audioBase64,
        'audioMimeType': audioMimeType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TranslatorQuickPhrase.fromJson(Map<String, dynamic> json) =>
      TranslatorQuickPhrase(
        id: json['id'],
        label: json['label'] ?? 'Quick phrase',
        translations: json['translations'] != null
            ? Map<String, String>.from(json['translations'])
            : <String, String>{},
        audioBase64: json['audioBase64'],
        audioMimeType: json['audioMimeType'],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );

  String textFor(String language) {
    if (translations.containsKey(language)) {
      return translations[language]!.trim();
    }
    if (translations.containsKey('English')) {
      return translations['English']!.trim();
    }
    return label;
  }
}

class ContentArticle {
  final String id;
  String title;
  String body;
  String category;
  String authorName;
  String authorId;
  DateTime createdAt;
  String? imageUrl;
  String status; // 'pending', 'approved', 'rejected'
  int views;
  int likes;
  bool isAdminPost;

  ContentArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.authorName,
    required this.authorId,
    required this.createdAt,
    this.imageUrl,
    this.status = 'pending',
    this.views = 0,
    this.likes = 0,
    this.isAdminPost = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'authorName': authorName,
        'authorId': authorId,
        'createdAt': createdAt.toIso8601String(),
        'imageUrl': imageUrl,
        'status': status,
        'views': views,
        'likes': likes,
        'isAdminPost': isAdminPost,
      };

  factory ContentArticle.fromJson(Map<String, dynamic> json) => ContentArticle(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        category: json['category'],
        authorName: json['authorName'],
        authorId: json['authorId'],
        createdAt: DateTime.parse(json['createdAt']),
        imageUrl: json['imageUrl'],
        status: json['status'] ?? 'pending',
        views: json['views'] ?? 0,
        likes: json['likes'] ?? 0,
        isAdminPost: json['isAdminPost'] ?? false,
      );
}

class TranslatorWordGamePrompt {
  final String id;
  String type; // scramble, translation, sentence
  String term;
  String translation;
  String? hint;
  String? sentenceTemplate;
  String? screenshotImageUrl;
  List<String> alternateAnswers;
  DateTime createdAt;
  DateTime? updatedAt;

  TranslatorWordGamePrompt({
    required this.id,
    this.type = 'scramble',
    required this.term,
    required this.translation,
    this.hint,
    this.sentenceTemplate,
    this.screenshotImageUrl,
    List<String>? alternateAnswers,
    DateTime? createdAt,
    this.updatedAt,
  })  : alternateAnswers = alternateAnswers ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'term': term,
        'translation': translation,
        'hint': hint,
        'sentenceTemplate': sentenceTemplate,
    'screenshotImageUrl': screenshotImageUrl,
        'alternateAnswers': alternateAnswers,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory TranslatorWordGamePrompt.fromJson(Map<String, dynamic> json) =>
      TranslatorWordGamePrompt(
        id: json['id'],
        type: json['type'] ?? 'scramble',
        term: json['term'] ?? '',
        translation: json['translation'] ?? '',
        hint: json['hint'],
        sentenceTemplate: json['sentenceTemplate'],
    screenshotImageUrl: json['screenshotImageUrl'],
        alternateAnswers: json['alternateAnswers'] != null
            ? List<String>.from(json['alternateAnswers'])
            : <String>[],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'])
            : null,
      );

  List<String> get allAcceptedAnswers {
    final buffer = <String>[];

    void addValue(String? value) {
      if (value == null || value.trim().isEmpty) {
        return;
      }
      final fragments = value.split(RegExp(r'[;,/|]'));
      if (fragments.length == 1) {
        buffer.add(value);
      } else {
        for (final fragment in fragments) {
          if (fragment.trim().isEmpty) {
            continue;
          }
          buffer.add(fragment);
        }
      }
    }

    addValue(term);
    addValue(translation);
    for (final alt in alternateAnswers) {
      addValue(alt);
    }

    return buffer
        .map((answer) => answer.trim())
        .where((answer) => answer.isNotEmpty)
        .toSet()
        .toList();
  }
}

class TranslatorWordGame {
  final String id;
  String title;
  String description;
  String gameStyle;
  bool isActive;
  List<TranslatorWordGamePrompt> prompts;
  int playCount;
  int bestScore;
  int bestOutOf;
  DateTime createdAt;
  DateTime? lastPlayedAt;

  TranslatorWordGame({
    required this.id,
    required this.title,
    required this.description,
    this.gameStyle = 'scramble',
    this.isActive = true,
    List<TranslatorWordGamePrompt>? prompts,
    this.playCount = 0,
    this.bestScore = 0,
    this.bestOutOf = 0,
    DateTime? createdAt,
    this.lastPlayedAt,
  })  : prompts = prompts ?? <TranslatorWordGamePrompt>[],
        createdAt = createdAt ?? DateTime.now();

  int get promptCount => prompts.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
    'gameStyle': gameStyle,
        'isActive': isActive,
        'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
        'playCount': playCount,
        'bestScore': bestScore,
        'bestOutOf': bestOutOf,
        'createdAt': createdAt.toIso8601String(),
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      };

  factory TranslatorWordGame.fromJson(Map<String, dynamic> json) =>
      TranslatorWordGame(
        id: json['id'],
        title: json['title'] ?? 'Word game',
        description: json['description'] ?? '',
    gameStyle: json['gameStyle'] ?? 'scramble',
        isActive: json['isActive'] ?? true,
        prompts: json['prompts'] != null
            ? (json['prompts'] as List)
                .map((prompt) =>
                    TranslatorWordGamePrompt.fromJson(prompt as Map<String, dynamic>))
                .toList()
            : <TranslatorWordGamePrompt>[],
        playCount: json['playCount'] ?? 0,
        bestScore: json['bestScore'] ?? 0,
        bestOutOf: json['bestOutOf'] ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        lastPlayedAt: json['lastPlayedAt'] != null
            ? DateTime.tryParse(json['lastPlayedAt'])
            : null,
      );
}

class QuizCategory {
  final String id;
  String name;
  IconData icon;
  bool isActive;

  QuizCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'isActive': isActive,
      };

  factory QuizCategory.fromJson(Map<String, dynamic> json) => QuizCategory(
        id: json['id'],
        name: json['name'],
        icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
        isActive: json['isActive'] ?? true,
      );
}

class TranslatorContributorProfile {
  final String id;
  String userId;
  String displayName;
  String status; // pending, approved, rejected
  DateTime requestedAt;
  DateTime? reviewedAt;
  String? reviewer;
  String? rejectionReason;
  int approvedCount;
  String? applicationNote;

  TranslatorContributorProfile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.status = 'pending',
    DateTime? requestedAt,
    this.reviewedAt,
    this.reviewer,
    this.rejectionReason,
    this.approvedCount = 0,
    this.applicationNote,
  }) : requestedAt = requestedAt ?? DateTime.now();

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'displayName': displayName,
        'status': status,
        'requestedAt': requestedAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewer': reviewer,
        'rejectionReason': rejectionReason,
        'approvedCount': approvedCount,
        'applicationNote': applicationNote,
      };

  factory TranslatorContributorProfile.fromJson(Map<String, dynamic> json) =>
      TranslatorContributorProfile(
        id: json['id'],
        userId: json['userId'],
        displayName: json['displayName'] ?? 'Contributor',
        status: json['status'] ?? 'pending',
        requestedAt: json['requestedAt'] != null
            ? DateTime.tryParse(json['requestedAt']) ?? DateTime.now()
            : DateTime.now(),
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.tryParse(json['reviewedAt'])
            : null,
        reviewer: json['reviewer'],
        rejectionReason: json['rejectionReason'],
        approvedCount: json['approvedCount'] ?? 0,
        applicationNote: json['applicationNote'],
      );
}

class TranslatorContributorSubmission {
  final String id;
  String contributorId;
  String contributorName;
  String sourceLanguage;
  String term;
  Map<String, String> translations;
  String status; // pending, approved, rejected
  DateTime submittedAt;
  DateTime? decidedAt;
  String? reviewer;
  String? reviewNote;
  String? partOfSpeech;
  String? example;
  String? audioBase64;
  String? audioMimeType;

  TranslatorContributorSubmission({
    required this.id,
    required this.contributorId,
    required this.contributorName,
    required this.sourceLanguage,
    required this.term,
    Map<String, String>? translations,
    this.status = 'pending',
    DateTime? submittedAt,
    this.decidedAt,
    this.reviewer,
    this.reviewNote,
    this.partOfSpeech,
    this.example,
    this.audioBase64,
    this.audioMimeType,
  })  : translations = translations ?? <String, String>{},
        submittedAt = submittedAt ?? DateTime.now();

  bool get isPending => status == 'pending';

  Map<String, dynamic> toJson() => {
        'id': id,
        'contributorId': contributorId,
        'contributorName': contributorName,
        'sourceLanguage': sourceLanguage,
        'term': term,
        'translations': translations,
        'status': status,
        'submittedAt': submittedAt.toIso8601String(),
        'decidedAt': decidedAt?.toIso8601String(),
        'reviewer': reviewer,
        'reviewNote': reviewNote,
        'partOfSpeech': partOfSpeech,
        'example': example,
        'audioBase64': audioBase64,
        'audioMimeType': audioMimeType,
      };

  factory TranslatorContributorSubmission.fromJson(
          Map<String, dynamic> json) =>
      TranslatorContributorSubmission(
        id: json['id'],
        contributorId: json['contributorId'],
        contributorName: json['contributorName'] ?? 'Contributor',
        sourceLanguage: json['sourceLanguage'] ?? 'English',
        term: json['term'] ?? '',
        translations: json['translations'] != null
            ? Map<String, String>.from(json['translations'])
            : <String, String>{},
        status: json['status'] ?? 'pending',
        submittedAt: json['submittedAt'] != null
            ? DateTime.tryParse(json['submittedAt']) ?? DateTime.now()
            : DateTime.now(),
        decidedAt: json['decidedAt'] != null
            ? DateTime.tryParse(json['decidedAt'])
            : null,
        reviewer: json['reviewer'],
        reviewNote: json['reviewNote'],
        partOfSpeech: json['partOfSpeech'],
        example: json['example'],
        audioBase64: json['audioBase64'],
        audioMimeType: json['audioMimeType'],
      );
}
