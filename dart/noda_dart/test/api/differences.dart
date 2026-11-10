// noda_dart: new code. Port of noda-js's ts/test/api/differences.ts. Keep in sync with dart/docs/api-differences/*.md.

const Map<String, String> notPorted = {
  // core.md
  'DateTimeOffsetExtensions': 'no Dart DateTimeOffset (core.md)',
  'DateOnlyExtensions': 'no Dart DateOnly (core.md)',
  'TimeOnlyExtensions': 'no Dart TimeOnly (core.md)',
  'TimeProviderExtensions': 'no Dart TimeProvider (core.md)',
  'DayOfWeekExtensions': 'Dart has no DayOfWeek type; an extension on int would pollute every int (core.md)',
  'ClockExtensions.InBclSystemDefaultZone': "DateTimeZoneProviders.Bcl is noda_dart's system library (core.md)",
  'Instant.ToDateTimeOffset': 'no Dart DateTimeOffset (core.md)',
  'Instant.FromDateTimeOffset': 'no Dart DateTimeOffset (core.md)',
  'Duration.ToInt128Nanoseconds': 'Dart has no Int128: ToBigIntegerNanoseconds gives a BigInt (core.md)',
  // local.md
  'LocalDate.ToDateOnly': 'no Dart DateOnly (local.md)',
  'LocalDate.FromDateOnly': 'no Dart DateOnly (local.md)',
  'LocalTime.ToTimeOnly': 'no Dart TimeOnly (local.md)',
  'LocalTime.FromTimeOnly': 'no Dart TimeOnly (local.md)',
  // period-offset.md
  'OffsetDateTime.ToDateTimeOffset': 'no Dart DateTimeOffset (period-offset.md)',
  'OffsetDateTime.FromDateTimeOffset': 'no Dart DateTimeOffset (period-offset.md)',
  // timezones.md
  'ZonedDateTime.ToDateTimeOffset': 'no Dart DateTimeOffset (timezones.md)',
  'ZonedDateTime.FromDateTimeOffset': 'no Dart DateTimeOffset (timezones.md)',
  'DateTimeZoneProviders.Bcl': "the system library's provider over SystemDateTimeZoneSource (timezones.md, system.md)",
  'DateTimeZoneProviders.Serialization': 'obsolete; XML (timezones.md)',
  'TzdbDateTimeZoneSource.FromStream': 'no System.IO.Stream in Dart: FromBytes / FromBase64 (timezones.md)',
  // text-core.md
  'TypeConverterSettings': '.NET TypeConverters (text-core.md)',
};

const Map<String, String> renamedTypes = {
  // system.md
  'BclDateTimeZone': 'SystemDateTimeZone',
  'BclDateTimeZoneSource': 'SystemDateTimeZoneSource',
};

const Map<String, String> renamed = {
  // core.md
  'Duration.FromTimeSpan': 'FromCoreDuration',
  'Duration.ToTimeSpan': 'ToCoreDuration',
  'Offset.FromTimeSpan': 'FromCoreDuration',
  'Offset.ToTimeSpan': 'ToCoreDuration',
};
