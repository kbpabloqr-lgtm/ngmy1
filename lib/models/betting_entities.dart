import 'package:flutter/material.dart';

/// Public enum representing each available betting mini-game.
enum GameType {
  wheel,
  slots,
  prizeBox,
  colorSpinner,
  moneyMania,
  magicTreasure,
  lgtJackpot,
  jackpotInferno,
  fortuneWheel,
  megaRoulette,
  coinFlip,
  diceDuel,
  penaltyShootout,
  horseSprint,
  crashMultiplier,
  cardDraw,
  rouletteRush,
  goalRush,
  boxingBout,
}

/// Immutable descriptor for a betting game used across the app.
class GameItem {
  const GameItem({
    required this.type,
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
    this.hidden = false,
  });

  final GameType type;
  final String title;
  final String description;
  final Color accent;
  final IconData icon;
  final bool hidden;
}

/// Standard catalogue of all available betting games.
const Map<GameType, GameItem> kGameCatalogue = {
  GameType.wheel: GameItem(
    type: GameType.wheel,
    title: 'Wheel of Fortune',
    description: 'Spin a cinematic wheel with classic casino odds.',
    accent: Color(0xFF7C9EFF),
    icon: Icons.casino_rounded,
  ),
  GameType.slots: GameItem(
    type: GameType.slots,
    title: 'Lucky Slots (legacy)',
    description: 'Legacy progressive slots. Hidden by default.',
    accent: Color(0xFFFFD54F),
    icon: Icons.view_column_rounded,
    hidden: true,
  ),
  GameType.prizeBox: GameItem(
    type: GameType.prizeBox,
    title: 'Prize Box (legacy)',
    description: 'Legacy mystery boxes. Hidden by default.',
    accent: Color(0xFF26A69A),
    icon: Icons.card_giftcard_rounded,
    hidden: true,
  ),
  GameType.colorSpinner: GameItem(
    type: GameType.colorSpinner,
    title: 'Color Spinner (legacy)',
    description: 'Legacy color spinner. Hidden by default.',
    accent: Color(0xFFEF5350),
    icon: Icons.palette_rounded,
    hidden: true,
  ),
  GameType.moneyMania: GameItem(
    type: GameType.moneyMania,
    title: 'Lucky Ticket Draw',
    description: 'Rip a premium ticket for instant multipliers up to 6x.',
    accent: Color(0xFF4CAF50),
    icon: Icons.casino_rounded,
  ),
  GameType.magicTreasure: GameItem(
    type: GameType.magicTreasure,
    title: 'Cash Storm Spin',
    description: 'Launch a rapid spin with safe returns and surprise boosts.',
    accent: Color(0xFFAF52DE),
    icon: Icons.auto_awesome_rounded,
  ),
  GameType.lgtJackpot: GameItem(
    type: GameType.lgtJackpot,
    title: 'Vault Breaker Spin',
    description: 'Charge the neon vault and chase stacked multipliers.',
    accent: Color(0xFF00B8D4),
    icon: Icons.inventory_2_rounded,
  ),
  GameType.jackpotInferno: GameItem(
    type: GameType.jackpotInferno,
    title: 'Heat Wave Spin',
    description: 'Surf the flames for aggressive multipliers and risk.',
    accent: Color(0xFFFF7043),
    icon: Icons.local_fire_department_rounded,
  ),
  GameType.fortuneWheel: GameItem(
    type: GameType.fortuneWheel,
    title: 'Fortune Wheel Royale',
    description: 'Premium wheel loaded with boosted money wedges.',
    accent: Color(0xFFFFC107),
    icon: Icons.circle_outlined,
    hidden: true,
  ),
  GameType.megaRoulette: GameItem(
    type: GameType.megaRoulette,
    title: 'Lightning Loop Spin',
    description: 'Short roulette loop that fires streak multipliers.',
    accent: Color(0xFF29B6F6),
    icon: Icons.stacked_line_chart,
  ),
  GameType.coinFlip: GameItem(
    type: GameType.coinFlip,
    title: 'Double or Nothing (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFF66BB6A),
    icon: Icons.monetization_on_rounded,
    hidden: true,
  ),
  GameType.diceDuel: GameItem(
    type: GameType.diceDuel,
    title: 'Dice Duel (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFF29B6F6),
    icon: Icons.casino_rounded,
    hidden: true,
  ),
  GameType.penaltyShootout: GameItem(
    type: GameType.penaltyShootout,
    title: 'Penalty Shootout (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFFFFA726),
    icon: Icons.sports_soccer,
    hidden: true,
  ),
  GameType.horseSprint: GameItem(
    type: GameType.horseSprint,
    title: 'Horse Sprint (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFFAB47BC),
    icon: Icons.directions_run,
    hidden: true,
  ),
  GameType.crashMultiplier: GameItem(
    type: GameType.crashMultiplier,
    title: 'Crash Run (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFFFF5252),
    icon: Icons.show_chart,
    hidden: true,
  ),
  GameType.cardDraw: GameItem(
    type: GameType.cardDraw,
    title: 'High Card Draw (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFF42A5F5),
    icon: Icons.style_rounded,
    hidden: true,
  ),
  GameType.rouletteRush: GameItem(
    type: GameType.rouletteRush,
    title: 'Roulette Rush (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFFFFD54F),
    icon: Icons.circle,
    hidden: true,
  ),
  GameType.goalRush: GameItem(
    type: GameType.goalRush,
    title: 'Goal Rush (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFF26A69A),
    icon: Icons.score,
    hidden: true,
  ),
  GameType.boxingBout: GameItem(
    type: GameType.boxingBout,
    title: 'Fight Night (retired)',
    description: 'Scenario betting game. Hidden for compatibility.',
    accent: Color(0xFFEF5350),
    icon: Icons.sports_mma,
    hidden: true,
  ),
};

/// Outcome data recorded whenever a game session completes.
class GameOutcome {
  GameOutcome({
    required this.game,
    required this.didWin,
    required this.stake,
    required this.payout,
    required this.detail,
    required this.timestamp,
  });

  final GameItem game;
  final bool didWin;
  final double stake;
  final double payout;
  final String detail;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'gameType': game.type.name,
        'didWin': didWin,
        'stake': stake,
        'payout': payout,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameOutcome.fromJson(Map<String, dynamic> json) {
    final gameTypeString = json['gameType'] as String;
    final gameType = GameType.values.firstWhere((e) => e.name == gameTypeString);
    final game = kGameCatalogue[gameType]!;
    
    return GameOutcome(
      game: game,
      didWin: json['didWin'] as bool,
      stake: (json['stake'] as num).toDouble(),
      payout: (json['payout'] as num).toDouble(),
      detail: json['detail'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Configuration for a single wheel segment with weighted probability.
class WheelSegmentConfig {
  WheelSegmentConfig({
    required this.id,
    required this.label,
    required this.multiplier,
    required this.color,
    this.weight = 10.0,
  });

  final String id;
  final String label;
  final double multiplier;
  final Color color;
  double weight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'multiplier': multiplier,
        'color': color.toARGB32(),
        'weight': weight,
      };

  factory WheelSegmentConfig.fromJson(Map<String, dynamic> json) {
    return WheelSegmentConfig(
      id: json['id'] as String,
      label: json['label'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      color: Color(json['color'] as int),
      weight: (json['weight'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

/// Configuration for Lucky Slots symbol probabilities.
class SlotSymbolConfig {
  SlotSymbolConfig({
    required this.id,
    required this.symbol,
    required this.label,
    required this.multiplier,
    required this.color,
    this.weight = 10.0,
    this.isProgressive = false,
  });

  final String id;
  final String symbol; // Emoji or text symbol
  final String label;
  final double multiplier; // Payout multiplier when 3 match
  final Color color;
  double weight;
  bool isProgressive;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'label': label,
        'multiplier': multiplier,
        'color': color.toARGB32(),
        'weight': weight,
        'isProgressive': isProgressive,
      };

  factory SlotSymbolConfig.fromJson(Map<String, dynamic> json) {
    return SlotSymbolConfig(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      label: json['label'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      color: Color(json['color'] as int),
      weight: (json['weight'] as num?)?.toDouble() ?? 10.0,
      isProgressive: json['isProgressive'] as bool? ?? false,
    );
  }
}

/// Configuration for Prize Box contents.
class PrizeBoxConfig {
  PrizeBoxConfig({
    required this.id,
    required this.label,
    required this.multiplier,
    required this.color,
    required this.icon,
    this.weight = 10.0,
  });

  final String id;
  final String label;
  final double multiplier;
  final Color color;
  final String icon; // Icon name as string
  double weight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'multiplier': multiplier,
        'color': color.toARGB32(),
        'icon': icon,
        'weight': weight,
      };

  factory PrizeBoxConfig.fromJson(Map<String, dynamic> json) {
    return PrizeBoxConfig(
      id: json['id'] as String,
      label: json['label'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      color: Color(json['color'] as int),
      icon: json['icon'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

/// Configuration for Color Spinner segments.
class ColorSegmentConfig {
  ColorSegmentConfig({
    required this.id,
    required this.label,
    required this.multiplier,
    required this.color,
    this.weight = 10.0,
  });

  final String id;
  final String label;
  final double multiplier;
  final Color color;
  double weight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'multiplier': multiplier,
        'color': color.toARGB32(),
        'weight': weight,
      };

  factory ColorSegmentConfig.fromJson(Map<String, dynamic> json) {
    return ColorSegmentConfig(
      id: json['id'] as String,
      label: json['label'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      color: Color(json['color'] as int),
      weight: (json['weight'] as num?)?.toDouble() ?? 10.0,
    );
  }
}
