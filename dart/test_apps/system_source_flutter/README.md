# system_source_test_app

A minimal Flutter app, for CI only, that runs `../system_source_checks` on every Flutter platform.

```sh
flutter pub get
# Android, iOS and desktop
flutter test integration_test -d <device> \
  --dart-define=NODA_EXPECT_SYSTEM_TIME_ZONE=<the device's zone>
# Web (chromedriver or safaridriver on port 4444)
flutter drive -d web-server --browser-name=chrome \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/system_source_test.dart
```

CI runs these through `dart/scripts/flutter/` (`desktop.ts`, `web.ts`, `android.ts`, `ios-simulator.ts`).

`NODA_EXPECT_SYSTEM_TIME_ZONE`: a Windows ID on Windows, an IANA ID elsewhere. Without it, the `GetSystemDefaultId`
check is skipped (on the web it's compared with `Intl`'s zone).
