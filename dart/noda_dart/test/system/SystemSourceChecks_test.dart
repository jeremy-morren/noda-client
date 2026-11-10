// noda_dart: new code. Runs dart/test_apps/system_source_checks (shared with the Flutter app) with package:test.
// NODA_EXPECT_SYSTEM_TIME_ZONE, if set, is the expected system zone ID.
@Tags(['system'])
library;

import 'package:system_source_checks/system_source_checks.dart';
import 'package:test/test.dart';

import 'Environment.dart';

// ignore: do_not_use_environment
const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

void main() {
  final platform = SystemSourcePlatform(
    name: PlatformName,
    backend: _isWeb
        ? SystemSourceBackend.intl
        : IsWindows
            ? SystemSourceBackend.windows
            : SystemSourceBackend.tzif,
    expectedSystemDefaultId: ReadEnvironment('NODA_EXPECT_SYSTEM_TIME_ZONE'),
    // noda_dart honours TZ on Windows; Dart's DateTime there (the C runtime) reads it as a POSIX TZ string.
    platformClockSkip:
        IsWindows && IsTZSet ? "TZ is set: Dart's DateTime on Windows doesn't read it as a zone ID" : null,
    // Like NodaTime, the tzdb provider maps TimeZoneInfo.Local's Windows ID, whose zone has DST.
    tzdbComparisonSkip: !IsTZSet && IsWindowsDaylightSavingTimeDisabled
        ? '"Adjust for daylight saving time automatically" is off: the tzdb provider maps the Windows ID, with DST'
        : null,
  );

  group('SystemDateTimeZoneSource', () {
    for (final check in systemSourceChecks(platform)) {
      test(check.name, check.body, skip: check.skip);
    }
  });
}
