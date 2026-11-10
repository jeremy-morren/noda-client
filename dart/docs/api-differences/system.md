# API differences: the system time zone source (`package:noda_dart/system.dart`)

| C# (NodaTime / .NET) | Dart (noda_dart) | Why |
|---|---|---|
| `BclDateTimeZoneSource` | `SystemDateTimeZoneSource` | As noda-js: the zones are the host system's, not a Base Class Library's. |
| `BclDateTimeZone` | `SystemDateTimeZone` | As noda-js. |
| `DateTimeZoneProviders.Bcl` | `SystemDateTimeZoneProvider` (top-level `final` in `system.dart`, created on first use) | No `DateTimeZoneProviders` registry (as noda-js): import a provider. |
| `BclDateTimeZone.BclAdjustmentRule` | `SystemDateTimeZoneBclAdjustmentRule` (internal) | Dart has no nested types. |
| `BclAdjustmentRule(ZoneInterval)` (internal ctor) | `SystemDateTimeZoneBclAdjustmentRule.NewZoneInterval` | Internal constructor naming rule. |
| `BclDateTimeZone.OriginalZone` (`TimeZoneInfo`) | `TimeZoneInfo? OriginalZone` | Null for zones from TZif files or Intl (only Windows has TimeZoneInfo data). |
| `BclDateTimeZone.DisplayName` | `DisplayName` | TZif zones: the ID; Intl zones: the host's English generic name, or the ID. |
| `BclDateTimeZone.AreWindowsStyleRules`, `FixUnixTransitions`, `BclAdjustmentRule.FromUnixAdjustmentRule`, `ConvertUnixRuleToBclAdjustmentRule` | Not ported | Unix zones come straight from TZif files (`System/TzifTimeZone.dart`). |
| `BclDateTimeZoneSource.VersionId` ("TimeZoneInfo: 4.0.0.0") | "TimeZoneInfo: Windows (dart:ffi)", "TZif: 2025b (/usr/share/zoneinfo)" or "Intl: 2025b" / "Intl: unknown" | Describes where the zones come from. |
| `BclDateTimeZoneSource.GetSystemDefaultId()` | Honours the `TZ` environment variable on every platform, Windows included (Windows or IANA ID, case-insensitive; anything else → UTC) | As noda-js; .NET on Windows ignores `TZ`. |
| `BclDateTimeZoneSource.ForId` throwing `ArgumentException` | throws `ArgumentError` | Exceptions map to Dart's errors. |
| `BclDateTimeZone.ForSystemDefault` throwing `InvalidOperationException` | throws `StateError` (or `DateTimeZoneNotFoundException` when `TZ` names no zone and there's no UTC) | Exceptions map to Dart's errors; `TZ` as noda-js. |
| `TimeZoneInfoInterceptor.ITimeZoneInfoShim` (internal) | `TimeZoneInfoInterceptorITimeZoneInfoShim` (internal), with `Backend` and `Description` | Dart has no nested types; the extra members describe the backend (as noda-js's). |
| `System.TimeZoneInfo` | `TimeZoneInfo`: the parts NodaTime uses. Public: `Id`, `DisplayName`, `StandardName`, `DaylightName`, `SupportsDaylightSavingTime`, `HasIanaId`; the rest is internal (TimeSpans as `int` ticks) | As noda-js. |
| `TimeZoneInfo.AdjustmentRule`, `TimeZoneInfo.TransitionTime` | `TimeZoneInfoAdjustmentRule`, `TimeZoneInfoTransitionTime` | Dart has no nested types. |
| `TimeZoneInfo.CreateCustomTimeZone` (three overloads) | One method with optional parameters: the four-parameter overload is the call without `daylightDisplayName` and `adjustmentRules` | Prefix chain. |
| `TimeZoneNotFoundException`, `InvalidTimeZoneException` | Same names, `implements Exception` (`System/`) | Dart has no equivalents. |
| `TimeZoneInfo.FindSystemTimeZoneById` with an IANA ID on Windows (ICU's mapping) | CLDR's windowsZones (as noda-js), after canonicalizing the ID with Windows' own ICU (`icu.dll`), case-insensitively | Native Dart has no Intl. |
| `TimeZoneInfo.Local` / `GetSystemTimeZones` on Unix (.NET's TZif reader) | `System/TzifSystemTimeZones.dart`: the zoneinfo directory (or Android's tzdata bundle) and `/etc/localtime` | Zone intervals from the TZif transitions; savings inferred from the last standard offset. |
