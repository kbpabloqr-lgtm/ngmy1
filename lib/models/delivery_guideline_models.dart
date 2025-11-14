import 'package:flutter/foundation.dart';

@immutable
class DeliveryInfoTile {
  const DeliveryInfoTile({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  DeliveryInfoTile copyWith({
    String? title,
    String? body,
  }) {
    return DeliveryInfoTile(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };

  factory DeliveryInfoTile.fromJson(Map<String, dynamic> json) {
    return DeliveryInfoTile(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class DeliveryScenarioData {
  const DeliveryScenarioData({
    required this.id,
    required this.label,
    required this.deliverBy,
    required this.orderValue,
    required this.orderCaption,
    required this.dashValue,
    required this.dashCaption,
    required this.deliveryForLabel,
    required this.customerName,
    required this.addressLine,
    required this.addressCity,
    required this.directionsLabel,
    required this.instructionTitle,
    required this.instructionBody,
    required this.itemsLabel,
    this.itemsDetail,
    this.secondaryTitle,
    this.secondaryBody,
    this.secondaryButtonLabel,
    this.merchantButtonLabel,
    this.equipmentPrimaryAction,
    this.equipmentSecondaryAction,
    this.bannerTitle,
    this.bannerBody,
    this.illustrationAsset,
    this.layout = 'pickup',
    List<DeliveryInfoTile>? infoTiles,
    required this.primaryButtonLabel,
  }) : infoTiles = infoTiles ?? const <DeliveryInfoTile>[];

  final String id;
  final String label;
  final String deliverBy;
  final String orderValue;
  final String orderCaption;
  final String dashValue;
  final String dashCaption;
  final String deliveryForLabel;
  final String customerName;
  final String addressLine;
  final String addressCity;
  final String directionsLabel;
  final String instructionTitle;
  final String instructionBody;
  final String itemsLabel;
  final String? itemsDetail;
  final String? secondaryTitle;
  final String? secondaryBody;
  final String? secondaryButtonLabel;
  final String? merchantButtonLabel;
  final String? equipmentPrimaryAction;
  final String? equipmentSecondaryAction;
  final String? bannerTitle;
  final String? bannerBody;
  final String? illustrationAsset;
  final String layout;
  final List<DeliveryInfoTile> infoTiles;
  final String primaryButtonLabel;

  DeliveryScenarioData copyWith({
    String? label,
    String? deliverBy,
    String? orderValue,
    String? orderCaption,
    String? dashValue,
    String? dashCaption,
    String? deliveryForLabel,
    String? customerName,
    String? addressLine,
    String? addressCity,
    String? directionsLabel,
    String? instructionTitle,
    String? instructionBody,
    String? itemsLabel,
    String? itemsDetail,
    String? secondaryTitle,
    String? secondaryBody,
    String? secondaryButtonLabel,
    String? merchantButtonLabel,
    String? equipmentPrimaryAction,
    String? equipmentSecondaryAction,
    String? bannerTitle,
    String? bannerBody,
    String? illustrationAsset,
    String? layout,
    List<DeliveryInfoTile>? infoTiles,
    String? primaryButtonLabel,
  }) {
    return DeliveryScenarioData(
      id: id,
      label: label ?? this.label,
      deliverBy: deliverBy ?? this.deliverBy,
      orderValue: orderValue ?? this.orderValue,
      orderCaption: orderCaption ?? this.orderCaption,
      dashValue: dashValue ?? this.dashValue,
      dashCaption: dashCaption ?? this.dashCaption,
      deliveryForLabel: deliveryForLabel ?? this.deliveryForLabel,
      customerName: customerName ?? this.customerName,
      addressLine: addressLine ?? this.addressLine,
      addressCity: addressCity ?? this.addressCity,
      directionsLabel: directionsLabel ?? this.directionsLabel,
      instructionTitle: instructionTitle ?? this.instructionTitle,
      instructionBody: instructionBody ?? this.instructionBody,
      itemsLabel: itemsLabel ?? this.itemsLabel,
      itemsDetail: itemsDetail ?? this.itemsDetail,
      secondaryTitle: secondaryTitle ?? this.secondaryTitle,
      secondaryBody: secondaryBody ?? this.secondaryBody,
      secondaryButtonLabel: secondaryButtonLabel ?? this.secondaryButtonLabel,
      merchantButtonLabel: merchantButtonLabel ?? this.merchantButtonLabel,
      equipmentPrimaryAction:
          equipmentPrimaryAction ?? this.equipmentPrimaryAction,
      equipmentSecondaryAction:
          equipmentSecondaryAction ?? this.equipmentSecondaryAction,
      bannerTitle: bannerTitle ?? this.bannerTitle,
      bannerBody: bannerBody ?? this.bannerBody,
      illustrationAsset: illustrationAsset ?? this.illustrationAsset,
      layout: layout ?? this.layout,
      infoTiles: infoTiles ?? this.infoTiles,
      primaryButtonLabel: primaryButtonLabel ?? this.primaryButtonLabel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'deliverBy': deliverBy,
      'orderValue': orderValue,
      'orderCaption': orderCaption,
      'dashValue': dashValue,
      'dashCaption': dashCaption,
      'deliveryForLabel': deliveryForLabel,
      'customerName': customerName,
      'addressLine': addressLine,
      'addressCity': addressCity,
      'directionsLabel': directionsLabel,
      'instructionTitle': instructionTitle,
      'instructionBody': instructionBody,
      'itemsLabel': itemsLabel,
      'itemsDetail': itemsDetail,
      'secondaryTitle': secondaryTitle,
      'secondaryBody': secondaryBody,
      'secondaryButtonLabel': secondaryButtonLabel,
      'merchantButtonLabel': merchantButtonLabel,
      'equipmentPrimaryAction': equipmentPrimaryAction,
      'equipmentSecondaryAction': equipmentSecondaryAction,
      'bannerTitle': bannerTitle,
      'bannerBody': bannerBody,
      'illustrationAsset': illustrationAsset,
      'layout': layout,
      'infoTiles': infoTiles.map((tile) => tile.toJson()).toList(),
      'primaryButtonLabel': primaryButtonLabel,
    };
  }

  factory DeliveryScenarioData.fromJson(Map<String, dynamic> json) {
    return DeliveryScenarioData(
      id: json['id'] as String? ?? UniqueKey().toString(),
      label: json['label'] as String? ?? 'Scenario',
      deliverBy: json['deliverBy'] as String? ?? 'Deliver by 4:01 PM',
      orderValue: json['orderValue'] as String? ?? '\$7.00',
      orderCaption: json['orderCaption'] as String? ?? 'this order',
      dashValue: json['dashValue'] as String? ?? '\$0.00',
      dashCaption: json['dashCaption'] as String? ?? 'this dash',
      deliveryForLabel: json['deliveryForLabel'] as String? ?? 'Delivery for',
      customerName: json['customerName'] as String? ?? 'Customer Name',
      addressLine: json['addressLine'] as String? ?? '123 Main St',
      addressCity: json['addressCity'] as String? ?? 'City, ST 00000',
      directionsLabel: json['directionsLabel'] as String? ?? 'Directions',
      instructionTitle:
          json['instructionTitle'] as String? ?? 'Delivery instruction',
      instructionBody: json['instructionBody'] as String? ?? 'Instruction',
      itemsLabel: json['itemsLabel'] as String? ?? 'Items',
      itemsDetail: json['itemsDetail'] as String?,
      secondaryTitle: json['secondaryTitle'] as String?,
      secondaryBody: json['secondaryBody'] as String?,
      secondaryButtonLabel: json['secondaryButtonLabel'] as String?,
      merchantButtonLabel: json['merchantButtonLabel'] as String?,
      equipmentPrimaryAction: json['equipmentPrimaryAction'] as String?,
      equipmentSecondaryAction: json['equipmentSecondaryAction'] as String?,
      bannerTitle: json['bannerTitle'] as String?,
      bannerBody: json['bannerBody'] as String?,
      illustrationAsset: json['illustrationAsset'] as String?,
      layout: json['layout'] as String? ?? 'pickup',
      infoTiles: (json['infoTiles'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) =>
              DeliveryInfoTile.fromJson(entry as Map<String, dynamic>))
          .toList(),
      primaryButtonLabel:
          json['primaryButtonLabel'] as String? ?? 'Complete delivery',
    );
  }
}
