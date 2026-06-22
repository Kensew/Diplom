import 'dart:convert';

import 'package:flutter_freelance_platform/services/customer_order_labels.dart';

class OrderComplexityResult {
  final int complexity;
  final int points;
  final List<OrderComplexityFactor> factors;

  const OrderComplexityResult({
    required this.complexity,
    required this.points,
    required this.factors,
  });

  String get factorsJson {
    return jsonEncode(
      factors
          .map(
            (factor) => {
              'code': factor.code,
              'label': factor.label,
              'points': factor.points,
            },
          )
          .toList(),
    );
  }
}

class OrderComplexityFactor {
  final String code;
  final String label;
  final int points;

  const OrderComplexityFactor({
    required this.code,
    required this.label,
    required this.points,
  });
}

class OrderComplexityService {
  const OrderComplexityService._();

  static OrderComplexityResult calculateAutoComplexity({
    required String description,
    required DateTime? deadline,
    required num? price,
    required bool requiresFiles,
    required bool requiresAuth,
    required bool requiresDatabase,
    required bool requiresApi,
    required bool requiresPayment,
    required int screensOrFunctionsCount,
  }) {
    final factors = <OrderComplexityFactor>[];

    void addFactor(String code, String label, int points) {
      if (points <= 0) return;

      factors.add(
        OrderComplexityFactor(code: code, label: label, points: points),
      );
    }

    if (requiresFiles) {
      addFactor(
        'files',
        CustomerOrderLabels.factorStoredLabel('files'),
        1,
      );
    }

    if (requiresAuth) {
      addFactor(
        'auth',
        CustomerOrderLabels.factorStoredLabel('auth'),
        1,
      );
    }

    if (requiresDatabase) {
      addFactor(
        'database',
        CustomerOrderLabels.factorStoredLabel('database'),
        1,
      );
    }

    if (requiresApi) {
      addFactor(
        'api',
        CustomerOrderLabels.factorStoredLabel('api'),
        1,
      );
    }

    if (requiresPayment) {
      addFactor(
        'payment',
        CustomerOrderLabels.factorStoredLabel('payment'),
        1,
      );
    }

    if (screensOrFunctionsCount >= 3 && screensOrFunctionsCount <= 5) {
      addFactor('screens_medium', 'Несколько страниц или разделов', 1);
    } else if (screensOrFunctionsCount > 5) {
      addFactor('screens_large', 'Много страниц или разделов', 2);
    }

    final normalizedDescription = description.trim();

    if (normalizedDescription.length >= 500 &&
        normalizedDescription.length < 1200) {
      addFactor('description_medium', 'Подробное описание задачи', 1);
    } else if (normalizedDescription.length >= 1200) {
      addFactor('description_large', 'Большой объём пожеланий', 2);
    }

    final now = DateTime.now();

    if (deadline != null) {
      final daysLeft =
          deadline.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (daysLeft <= 2) {
        addFactor('deadline_urgent', 'Очень короткий срок', 2);
      } else if (daysLeft <= 5) {
        addFactor('deadline_short', 'Короткий срок', 1);
      }
    }

    final safePrice = price ?? 0;

    if (safePrice >= 30000 && safePrice < 80000) {
      addFactor('price_medium', 'Средний бюджет', 1);
    } else if (safePrice >= 80000) {
      addFactor('price_high', 'Высокий бюджет', 2);
    }

    final points = factors.fold<int>(0, (sum, factor) => sum + factor.points);

    return OrderComplexityResult(
      complexity: _pointsToComplexity(points),
      points: points,
      factors: factors,
    );
  }

  static int _pointsToComplexity(int points) {
    if (points <= 1) return 1;
    if (points <= 3) return 2;
    if (points <= 5) return 3;
    if (points <= 7) return 4;
    return 5;
  }

  static int clampProposedComplexity({
    required int autoComplexity,
    required int proposedComplexity,
  }) {
    final minValue = (autoComplexity - 1).clamp(1, 5);
    final maxValue = (autoComplexity + 1).clamp(1, 5);

    return proposedComplexity.clamp(minValue, maxValue);
  }

  static List<int> allowedProposedValues(int autoComplexity) {
    final minValue = (autoComplexity - 1).clamp(1, 5);
    final maxValue = (autoComplexity + 1).clamp(1, 5);

    return [for (var value = minValue; value <= maxValue; value++) value];
  }

  static String complexityLabel(int? complexity) {
    switch (complexity) {
      case 1:
        return 'Простая';
      case 2:
        return 'Ниже средней';
      case 3:
        return 'Средняя';
      case 4:
        return 'Сложная';
      case 5:
        return 'Высокая';
      default:
        return 'Не рассчитана';
    }
  }

  static String complexityShortText(int? complexity) {
    if (complexity == null) return '—';
    return '$complexity / 5';
  }

  static String sourceLabel(String? source) {
    switch (source) {
      case 'auto':
        return 'Системная оценка';
      case 'executor_adjusted':
        return 'Оценка исполнителя';
      case 'support_adjusted':
        return 'Изменено поддержкой';
      default:
        return 'Не указано';
    }
  }

  static List<OrderComplexityFactor> parseFactors(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawJson);

      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => OrderComplexityFactor(
              code: item['code']?.toString() ?? '',
              label: item['label']?.toString() ?? '',
              points: (item['points'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((factor) => factor.code.isNotEmpty && factor.label.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
