import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_guideline_models.dart';

class DeliveryGuidelineStore extends ChangeNotifier {
  DeliveryGuidelineStore._();

  static final DeliveryGuidelineStore instance = DeliveryGuidelineStore._();

  final List<DeliveryScenarioData> _scenarios = <DeliveryScenarioData>[];
  bool _loaded = false;

  List<DeliveryScenarioData> get scenarios => List.unmodifiable(_scenarios);

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('delivery_guideline_state');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _scenarios
          ..clear()
          ..addAll(decoded.map((entry) =>
              DeliveryScenarioData.fromJson(entry as Map<String, dynamic>)));
      } catch (error, stackTrace) {
        debugPrint('Failed to parse delivery guideline state: $error');
        debugPrint('$stackTrace');
        _scenarios
          ..clear()
          ..addAll(_defaultScenarios());
      }
    } else {
      _scenarios
        ..clear()
        ..addAll(_defaultScenarios());
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> updateScenario(DeliveryScenarioData updated) async {
    await load();
    final index =
        _scenarios.indexWhere((scenario) => scenario.id == updated.id);
    if (index == -1) {
      return;
    }

    _scenarios[index] = updated;
    await _save();
    notifyListeners();
  }

  DeliveryScenarioData? findById(String id) {
    if (_scenarios.isEmpty) {
      return null;
    }
    try {
      return _scenarios.firstWhere((scenario) => scenario.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> resetToDefaults() async {
    _scenarios
      ..clear()
      ..addAll(_defaultScenarios());
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _scenarios.map((scenario) => scenario.toJson()).toList(),
    );
    await prefs.setString('delivery_guideline_state', encoded);
  }

  List<DeliveryScenarioData> _defaultScenarios() {
    return <DeliveryScenarioData>[
      DeliveryScenarioData(
        id: 'pizza_pickup_verification',
        label: 'Pizza pickup start',
        deliverBy: 'Deliver by 4:01 PM',
        orderValue: '\$12.25',
        orderCaption: 'this order',
        dashValue: '\$45.00',
        dashCaption: 'today',
        deliveryForLabel: 'Order for',
        customerName: 'Shelly Wright',
        addressLine: "Pete's Pizza · 500 W 2nd St",
        addressCity: 'Austin, TX 78701',
        directionsLabel: 'Directions',
        instructionTitle: 'Please verify your Pizza Bag',
        instructionBody:
            'This equipment is required for pizza orders. Snap a quick photo before you grab the order.',
        itemsLabel: '3 items',
        itemsDetail: '2 Large pepperoni · 1 Garlic knots',
        merchantButtonLabel: 'Show order to merchant',
  equipmentPrimaryAction: 'Take photo',
        equipmentSecondaryAction: "I don't have one right now",
  primaryButtonLabel: 'Confirm pickup',
        infoTiles: <DeliveryInfoTile>[
          const DeliveryInfoTile(
            id: 'items_overview',
            title: '3 items',
            body: '2 Large Pepperoni · 1 Garlic Knots',
          ),
          const DeliveryInfoTile(
            id: 'entry_instructions',
            title: 'Walk into store',
            body: 'Enter from the 2nd Street side next to the parking garage.',
          ),
          const DeliveryInfoTile(
            id: 'pickup_details',
            title: 'Food on shelf',
            body:
                'Pickup shelf is along the left wall. Orders are labeled by customer name.',
          ),
        ],
      ),
      DeliveryScenarioData(
        id: 'pizza_bag_reminder',
        label: 'Pizza bag reminder',
        deliverBy: 'Deliver by 4:01 PM',
        orderValue: '\$12.25',
        orderCaption: 'this order',
        dashValue: '\$45.00',
        dashCaption: 'today',
        deliveryForLabel: 'Friendly reminder',
        customerName: 'Pizza bag check',
        addressLine: "Pete's Pizza",
        addressCity: 'Austin, TX 78701',
        directionsLabel: 'Directions',
        instructionTitle: 'Keep using your pizza bag',
        instructionBody:
            'Pizza bags keep food hot and customers happy. Make sure to bring it on every pizza order.',
        itemsLabel: 'Reminder',
        bannerTitle: "Don't forget your pizza bag next time",
        bannerBody:
            'We noticed you confirmed a pizza pickup without verifying your pizza bag. Use it to keep orders warm during delivery.',
        primaryButtonLabel: 'Got it',
        layout: 'reminder',
      ),
      DeliveryScenarioData(
        id: 'pizza_pickup_followup',
        label: 'Pizza pickup follow-up',
        deliverBy: 'Deliver by 4:01 PM',
        orderValue: '\$12.25',
        orderCaption: 'this order',
        dashValue: '\$45.00',
        dashCaption: 'today',
        deliveryForLabel: 'Order for',
        customerName: 'Shelly Wright',
        addressLine: "Pete's Pizza · 500 W 2nd St",
        addressCity: 'Austin, TX 78701',
        directionsLabel: 'Directions',
        instructionTitle: 'Pizza bags are required for pizza orders',
        instructionBody:
            'Dashers keep pizzas warm by using a pizza bag. We ask that you use one for every pizza pickup.',
        itemsLabel: '3 items',
        itemsDetail: '2 Large pepperoni · 1 Garlic knots',
        bannerTitle: 'Pizza bags are required for pizza orders',
        bannerBody:
            'To keep food hot and customers satisfied, confirm your pizza bag before leaving the store.',
  primaryButtonLabel: 'Confirm pickup',
        infoTiles: <DeliveryInfoTile>[
          const DeliveryInfoTile(
            id: 'items_overview_followup',
            title: '3 items',
            body: '2 Large Pepperoni · 1 Garlic Knots',
          ),
          const DeliveryInfoTile(
            id: 'entry_instructions_followup',
            title: 'Walk into store',
            body: 'Enter from the 2nd Street side next to the parking garage.',
          ),
          const DeliveryInfoTile(
            id: 'pickup_details_followup',
            title: 'Pickup spot',
            body:
                'Food is on the heated shelf left of the counter. Orders are labeled with the customer name.',
          ),
          const DeliveryInfoTile(
            id: 'contact_support_followup',
            title: "Need help at Pete's Pizza?",
            body:
                'Call support if you cannot locate the order or have questions about the pizza bag policy.',
          ),
        ],
      ),
    ];
  }
}
