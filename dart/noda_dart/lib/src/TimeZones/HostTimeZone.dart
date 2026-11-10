// noda_dart: new code. The host's current zone, standing in for TimeZoneInfo.Local in the tzdb source's
// MapTimeZoneInfoId.

import 'dart:core';
import 'dart:core' as core show DateTime;

import 'package:meta/meta.dart';

import '../Instant.dart';
import '../Offset.dart';
import '../System/Host.dart' as host;
import '../Utility/TimeZoneEnvironment.dart';

/// The parts of a TimeZoneInfo that TzdbDateTimeZoneSource.MapTimeZoneInfoId uses: its ID and its UTC offsets.
@internal
abstract interface class IHostTimeZone {
  /// The zone's ID: a Windows ID, a tzdb ID, or "Local" when the host can't name it.
  String get Id;

  /// Whether the ID is TZ's (then an unmapped ID means UTC rather than being guessed).
  bool get FromEnvironment;

  /// TimeZoneInfo.GetUtcOffset for an instant.
  Offset GetUtcOffset(Instant instant);
}

/// The ID Mono's TimeZoneInfo.Local has when it can't name the zone; also noda_dart's.
const String _LocalId = 'Local';

final class _HostTimeZone implements IHostTimeZone {
  @override
  final String Id;
  @override
  final bool FromEnvironment;

  _HostTimeZone(this.Id, this.FromEnvironment);

  @override
  Offset GetUtcOffset(Instant instant) => _DateUtcOffset(instant);
}

/// The host's current zone: TZ's if set, else the host's ("Local" if unnamed), with dart:core's offsets.
@internal
IHostTimeZone GetHostTimeZone() {
  final tz = GetTZEnvironmentVariable();
  final id = tz ?? host.GetHostLocalTimeZoneId() ?? _LocalId;
  return _HostTimeZone(id, tz != null);
}

/// The host's local UTC offset at an instant, from dart:core's DateTime (to the second).
Offset _DateUtcOffset(Instant instant) {
  final offset = core.DateTime.fromMillisecondsSinceEpoch(instant.ToUnixTimeMilliseconds()).timeZoneOffset;
  return Offset.FromSeconds(offset.inSeconds);
}
