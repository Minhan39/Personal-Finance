import 'dart:async';

import 'package:flutter/cupertino.dart';

class FallbackStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final Stream<T> fallbackStream;

  const FallbackStreamTransformer({required this.fallbackStream});

  @override
  Stream<T> bind(Stream<T> primary) {
    final controller = StreamController<T>.broadcast();
    StreamSubscription<T>? primarySub;
    StreamSubscription<T>? fallbackSub;
    bool usingFallback = false;

    void switchToFallback() {
      if (usingFallback) return;
      usingFallback = true;
      primarySub?.cancel();
      primarySub = null;

      fallbackSub = fallbackStream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    }

    primarySub = primary.listen(
      controller.add,
      onError: (e, st) {
        debugPrint('Primary stream error, switching to fallback: $e');
        switchToFallback();
      },
      onDone: () {
        if (!usingFallback) controller.close();
      },
    );

    controller.onCancel = () {
      primarySub?.cancel();
      fallbackSub?.cancel();
    };

    return controller.stream;
  }
}
