// Runs ../system_source_checks on a device (see README.md).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:system_source_checks/system_source_checks.dart';

const _expectedZone = String.fromEnvironment('NODA_EXPECT_SYSTEM_TIME_ZONE');
// Why DateTime's offsets may not match the system default (e.g. TZ on Windows, which DateTime ignores).
const _platformClockSkip = String.fromEnvironment('NODA_PLATFORM_CLOCK_SKIP');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = SystemSourcePlatform(
    name: 'Flutter on ${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    backend: kIsWeb
        ? SystemSourceBackend.intl
        : defaultTargetPlatform == TargetPlatform.windows
            ? SystemSourceBackend.windows
            : SystemSourceBackend.tzif,
    expectedSystemDefaultId: _expectedZone.isEmpty ? null : _expectedZone,
    platformClockSkip: _platformClockSkip.isEmpty ? null : _platformClockSkip,
  );

  group('SystemDateTimeZoneSource', () {
    for (final check in systemSourceChecks(platform)) {
      test(check.name, check.body, skip: check.skip);
    }
  });
}
