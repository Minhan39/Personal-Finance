import 'package:flutter/cupertino.dart';

class SourceCircuitBreaker {
  static const int maxFailures = 3;

  static final Map<String, int> _consecutiveFailures = {};
  static final Set<String> _disabledSources = {};

  static bool canUse(String sourceKey) => !_disabledSources.contains(sourceKey);

  static void markSuccess(String sourceKey) {
    _consecutiveFailures[sourceKey] = 0;
    _disabledSources.remove(sourceKey);
  }

  static bool markFailure(String sourceKey) {
    final failures = (_consecutiveFailures[sourceKey] ?? 0) + 1;
    _consecutiveFailures[sourceKey] = failures;
    if (failures >= maxFailures) {
      _disabledSources.add(sourceKey);
      return true;
    }
    return false;
  }
}

typedef SourceFetch<T> = Future<List<T>> Function();
typedef SourceWrite<T> = Future<bool> Function(T item);
typedef SourceId<T> = String Function(T item);
typedef SourceSort<T> = List<T> Function(List<T> items);

Future<List<T>> reconcileBetweenSources<T>({
  required String primarySourceKey,
  required String fallbackSourceKey,
  required String logLabel,
  required SourceFetch<T> primaryFetch,
  required SourceFetch<T> fallbackFetch,
  required SourceWrite<T> pushToPrimary,
  required SourceWrite<T> pushToFallback,
  required SourceId<T> itemId,
  required SourceSort<T> sortItems,
}) async {
  List<T>? primaryItems;
  List<T>? fallbackItems;

  if (SourceCircuitBreaker.canUse(primarySourceKey)) {
    try {
      primaryItems = await primaryFetch();
      SourceCircuitBreaker.markSuccess(primarySourceKey);
    } catch (error) {
      debugPrint('$logLabel primary fetch failed: $error');
      SourceCircuitBreaker.markFailure(primarySourceKey);
    }
  }

  if (SourceCircuitBreaker.canUse(fallbackSourceKey)) {
    try {
      fallbackItems = await fallbackFetch();
      SourceCircuitBreaker.markSuccess(fallbackSourceKey);
    } catch (error) {
      debugPrint('$logLabel fallback fetch failed: $error');
      SourceCircuitBreaker.markFailure(fallbackSourceKey);
    }
  }

  if (primaryItems == null && fallbackItems == null) {
    return const [];
  }

  if (primaryItems != null && fallbackItems != null) {
    await _syncMissingItems(
      logLabel: logLabel,
      primarySourceKey: primarySourceKey,
      fallbackSourceKey: fallbackSourceKey,
      primaryItems: primaryItems,
      fallbackItems: fallbackItems,
      pushToPrimary: pushToPrimary,
      pushToFallback: pushToFallback,
      itemId: itemId,
    );
  }

  final merged = <String, T>{};
  for (final item in <T>[
    ...?primaryItems,
    ...?fallbackItems,
  ]) {
    final id = itemId(item);
    if (id.isEmpty) {
      continue;
    }
    merged[id] = item;
  }

  return sortItems(merged.values.toList());
}

Future<void> _syncMissingItems<T>({
  required String logLabel,
  required String primarySourceKey,
  required String fallbackSourceKey,
  required List<T> primaryItems,
  required List<T> fallbackItems,
  required SourceWrite<T> pushToPrimary,
  required SourceWrite<T> pushToFallback,
  required SourceId<T> itemId,
}) async {
  final primaryIndex = {
    for (final item in primaryItems)
      if (itemId(item).isNotEmpty) itemId(item): item,
  };
  final fallbackIndex = {
    for (final item in fallbackItems)
      if (itemId(item).isNotEmpty) itemId(item): item,
  };

  final missingInPrimary = fallbackIndex.entries
      .where((entry) => !primaryIndex.containsKey(entry.key))
      .map((entry) => entry.value)
      .toList();

  final missingInFallback = primaryIndex.entries
      .where((entry) => !fallbackIndex.containsKey(entry.key))
      .map((entry) => entry.value)
      .toList();

  if (missingInPrimary.isNotEmpty) {
    for (final item in missingInPrimary) {
      try {
        final synced = await pushToPrimary(item);
        if (!synced) {
          SourceCircuitBreaker.markFailure(primarySourceKey);
        } else {
          SourceCircuitBreaker.markSuccess(primarySourceKey);
        }
      } catch (error) {
        debugPrint('$logLabel sync to primary failed: $error');
        SourceCircuitBreaker.markFailure(primarySourceKey);
      }
    }
  }

  if (missingInFallback.isNotEmpty) {
    for (final item in missingInFallback) {
      try {
        final synced = await pushToFallback(item);
        if (!synced) {
          SourceCircuitBreaker.markFailure(fallbackSourceKey);
        } else {
          SourceCircuitBreaker.markSuccess(fallbackSourceKey);
        }
      } catch (error) {
        debugPrint('$logLabel sync to fallback failed: $error');
        SourceCircuitBreaker.markFailure(fallbackSourceKey);
      }
    }
  }
}
