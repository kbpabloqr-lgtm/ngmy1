import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

class CountryOption {
  final String code;
  final String name;
  final String currencyCode;
  final String currencySymbol;
  final double usdToLocalRate;
  final String region;

  const CountryOption({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.usdToLocalRate,
    required this.region,
  });

  String formatLocalAmount(double usdAmount, {int decimals = 2}) {
    final localValue = usdAmount * usdToLocalRate;
    return _formatNumber(localValue, decimals: decimals);
  }

  String formatUsd(double usdAmount, {int decimals = 2}) {
    return _formatNumber(usdAmount, decimals: decimals);
  }

  static String _formatNumber(num value, {int decimals = 0}) {
    final isNegative = value.isNegative;
    final absolute = value.abs();
    final fixed = absolute.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final buffer = StringBuffer();

    for (int i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final digitsLeft = integerPart.length - i - 1;
      if (digitsLeft > 0 && digitsLeft % 3 == 0) {
        buffer.write(',');
      }
    }

    final decimalsPart =
        (decimals > 0 && parts.length > 1) ? '.${parts[1]}' : '';
    final sign = isNegative ? '-' : '';
    return '$sign${buffer.toString()}$decimalsPart';
  }
}

class LocationDetectionResult {
  final CountryOption? country;
  final Position? position;
  final bool confidenceHigh;
  final String? error;

  const LocationDetectionResult({
    required this.country,
    required this.position,
    required this.confidenceHigh,
    this.error,
  });

  double? get latitude => position?.latitude;
  double? get longitude => position?.longitude;
  double? get accuracyMeters => position?.accuracy;
}

class CountryLocationService {
  static const double _highConfidenceAccuracyMeters = 1000;
  static const double _systemUsdToNgRate = 650.0;

  static final Map<String, CountryOption> _options = {
    'TZ': const CountryOption(
      code: 'TZ',
      name: 'Tanzania',
      currencyCode: 'TZS',
      currencySymbol: 'TZS',
      usdToLocalRate: 2452.52,
      region: 'africa',
    ),
    'CD': const CountryOption(
      code: 'CD',
      name: 'Congo',
      currencyCode: 'CDF',
      currencySymbol: 'CDF',
      usdToLocalRate: 2295.85,
      region: 'africa',
    ),
    'GH': const CountryOption(
      code: 'GH',
      name: 'Ghana',
      currencyCode: 'GHS',
      currencySymbol: 'GHS',
      usdToLocalRate: 10.91,
      region: 'africa',
    ),
    'KE': const CountryOption(
      code: 'KE',
      name: 'Kenya',
      currencyCode: 'KES',
      currencySymbol: 'KES',
      usdToLocalRate: 127.61,
      region: 'africa',
    ),
    'BI': const CountryOption(
      code: 'BI',
      name: 'Burundi',
      currencyCode: 'BIF',
      currencySymbol: 'BIF',
      usdToLocalRate: 2947.68,
      region: 'africa',
    ),
    'US': const CountryOption(
      code: 'US',
      name: 'United States',
      currencyCode: 'NGX',
      currencySymbol: '₦₲',
      usdToLocalRate: _systemUsdToNgRate,
      region: 'system',
    ),
  };

  static List<CountryOption> get supportedCountries =>
      _options.values.toList(growable: false);

  static CountryOption get defaultCountry => _options['US']!;

  static CountryOption? optionForCode(String? code) {
    if (code == null) {
      return null;
    }
    final normalized = code.trim().toUpperCase();
    return _options[normalized];
  }

  static bool shareRegion(CountryOption detected, CountryOption other) {
    return detected.region == other.region;
  }

  static Future<LocationDetectionResult> detectCountry() async {
    try {
      final hasPermission = await _ensurePermission();
      if (!hasPermission) {
        return const LocationDetectionResult(
          country: null,
          position: null,
          confidenceHigh: false,
          error: 'Location permission denied',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 10));

      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'en',
      );

      geocoding.Placemark? primary;
      if (placemarks.isNotEmpty) {
        primary = placemarks.first;
      }

      CountryOption? matched;
      if (primary != null) {
        matched = optionForCode(primary.isoCountryCode);
      }

      final confidenceHigh =
          matched != null &&
          position.accuracy <= _highConfidenceAccuracyMeters;

      return LocationDetectionResult(
        country: matched,
        position: position,
        confidenceHigh: confidenceHigh,
      );
    } on TimeoutException {
      return const LocationDetectionResult(
        country: null,
        position: null,
        confidenceHigh: false,
        error: 'Location request timed out',
      );
    } catch (error) {
      return LocationDetectionResult(
        country: null,
        position: null,
        confidenceHigh: false,
        error: error.toString(),
      );
    }
  }

  static Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return false;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static double? distanceMeters(
    double? latitude,
    double? longitude,
    Position? reference,
  ) {
    if (latitude == null || longitude == null || reference == null) {
      return null;
    }

    const double earthRadius = 6371000; // meters
    final double lat1 = _degreesToRadians(reference.latitude);
    final double lon1 = _degreesToRadians(reference.longitude);
    final double lat2 = _degreesToRadians(latitude);
    final double lon2 = _degreesToRadians(longitude);

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a =
        math.pow(math.sin(dLat / 2), 2).toDouble() +
            math.cos(lat1) *
                math.cos(lat2) *
                math.pow(math.sin(dLon / 2), 2).toDouble();
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
