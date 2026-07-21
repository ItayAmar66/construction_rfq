import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:construction_rfq/providers/connectivity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isOfflineProvider', () {
    test('is false while the first connectivity reading is pending', () {
      final container = ProviderContainer(
        overrides: [
          connectivityStatusProvider.overrideWith(
            (ref) => const Stream<List<ConnectivityResult>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(isOfflineProvider), isFalse);
    });

    test('is true when every reported interface is none', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStatusProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.none]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectivityStatusProvider.future);
      expect(container.read(isOfflineProvider), isTrue);
    });

    test('is false when wifi is reported', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStatusProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.wifi]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectivityStatusProvider.future);
      expect(container.read(isOfflineProvider), isFalse);
    });
  });
}
