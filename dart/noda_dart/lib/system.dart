/// The host system's time zones: NodaTime's `BclDateTimeZoneSource` and `DateTimeZoneProviders.Bcl`.
library;

import 'src/IDateTimeZoneProvider.dart';
import 'src/TimeZones/DateTimeZoneCache.dart';
import 'src/TimeZones/SystemDateTimeZoneSource.dart';

export 'src/System/InvalidTimeZoneException.dart' show InvalidTimeZoneException;
export 'src/System/TimeZoneInfo.AdjustmentRule.dart' show TimeZoneInfoAdjustmentRule;
export 'src/System/TimeZoneInfo.TransitionTime.dart' show TimeZoneInfoTransitionTime;
export 'src/System/TimeZoneInfo.dart' show TimeZoneInfo;
export 'src/System/TimeZoneNotFoundException.dart' show TimeZoneNotFoundException;
export 'src/TimeZones/SystemDateTimeZone.dart' show SystemDateTimeZone;
export 'src/TimeZones/SystemDateTimeZoneSource.dart' show SystemDateTimeZoneSource;

/// A provider for the host system's time zones (NodaTime's `DateTimeZoneProviders.Bcl`).
final IDateTimeZoneProvider SystemDateTimeZoneProvider = DateTimeZoneCache(SystemDateTimeZoneSource());
