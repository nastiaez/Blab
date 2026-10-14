import 'dart:async';
import 'package:blab/shared/services/stream_push_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authorized original cache finishes before visible notification',
    () async {
      final sequence = <String>[];
      final result = await prepareStreamPush(
        accountStillCurrent: () => true,
        cache: () async {
          sequence.add('cache');
        },
        show: () async {
          sequence.add('show');
        },
      );
      expect(sequence, ['cache', 'show']);
      expect(result, StreamPushPreparation.cached);
    },
  );
  test(
    'a slow network cannot delay notification indefinitely or trigger AI',
    () async {
      final pending = Completer<void>();
      var shown = false;
      final result = await prepareStreamPush(
        accountStillCurrent: () => true,
        cache: () => pending.future,
        show: () async {
          shown = true;
        },
        budget: const Duration(milliseconds: 10),
      );
      expect(shown, true);
      expect(result, StreamPushPreparation.fallback);
      pending.complete();
    },
  );
  test(
    'identity change while preparing suppresses old-account notification',
    () async {
      var current = true;
      var shown = false;
      final result = await prepareStreamPush(
        accountStillCurrent: () => current,
        cache: () async {
          current = false;
        },
        show: () async {
          shown = true;
        },
      );
      expect(shown, false);
      expect(result, StreamPushPreparation.ignored);
    },
  );
  test(
    'an old-account push starts neither cache fetch nor notification',
    () async {
      var called = false;
      final result = await prepareStreamPush(
        accountStillCurrent: () => false,
        cache: () async {
          called = true;
        },
        show: () async {
          called = true;
        },
      );
      expect(called, false);
      expect(result, StreamPushPreparation.ignored);
    },
  );
}
