// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/FixedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import '../LocalDateTime.dart';
// FixedDateTimeZone has a member named Offset, which hides the type inside the class.
import '../Offset.dart' as nt show Offset;
import '../Text/OffsetPattern.dart';
import '../Utility/HashCodeHelper.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'ZoneInterval.dart';
import 'ZoneLocalMapping.dart';

// Implementation note: this implemented IEquatable<FixedDateTimeZone> for the sake of fitting in with our test infrastructure
// more than anything else...

/// Basic [DateTimeZone] implementation that has a fixed name key and offset i.e.
/// no daylight savings.
@internal
final class FixedDateTimeZone extends DateTimeZone {
  final ZoneInterval _interval;

  /// Creates a new fixed time zone.
  ///
  /// The ID and name (for the [ZoneInterval]) are generated based on the offset.
  ///
  /// [offset]: The [nt.Offset] from UTC.
  @internal
  FixedDateTimeZone.NewOffset(nt.Offset offset) : this.NewIdOffset(_MakeId(offset), offset);

  /// Initializes a new instance of the [FixedDateTimeZone] class.
  ///
  /// The name (for the [ZoneInterval]) is deemed to be the same as the ID.
  ///
  /// [id]: The id.
  /// [offset]: The offset.
  @internal
  FixedDateTimeZone.NewIdOffset(String id, nt.Offset offset) : this.NewIdOffsetName(id, offset, id);

  /// Initializes a new instance of the [FixedDateTimeZone] class.
  ///
  /// The name (for the [ZoneInterval]) is deemed to be the same as the ID.
  ///
  /// [id]: The id.
  /// [offset]: The offset.
  /// [name]: The name to use in the sole [ZoneInterval] in this zone.
  @internal
  FixedDateTimeZone.NewIdOffsetName(String id, nt.Offset offset, String name)
      : _interval = ZoneInterval.NewNameStartEndWallOffsetSavings(
            name, Instant.BeforeMinValue, Instant.AfterMaxValue, offset, nt.Offset.Zero),
        super(id, true, offset, offset);

  /// Makes the id for this time zone. The format is "UTC+/-Offset".
  ///
  /// [offset]: The offset.
  ///
  /// Returns the generated id string.
  static String _MakeId(nt.Offset offset) {
    if (offset == nt.Offset.Zero) {
      return DateTimeZone.UtcId;
    }

    // This code is equivalent to
    // UtcId + OffsetPattern.GeneralInvariant.Format(offset)
    // but avoids using any code in NodaTime.Text, which can cause
    // issues during type initialization.
    var absSeconds = offset.Seconds.abs();
    var hours = absSeconds ~/ 3600;
    var minutes = absSeconds.remainder(3600) ~/ 60;
    var seconds = absSeconds.remainder(60);

    // Dart: hours.ToString("00", CultureInfo.InvariantCulture) etc.
    String d2(int value) => value.toString().padLeft(2, '0');
    String absString = minutes == 0 && seconds == 0
        ? d2(hours)
        : seconds == 0
            ? '${d2(hours)}:${d2(minutes)}'
            : '${d2(hours)}:${d2(minutes)}:${d2(seconds)}';

    var prefixAndSign = offset.Seconds < 0 ? ('${DateTimeZone.UtcId}-') : ('${DateTimeZone.UtcId}+');
    return prefixAndSign + absString;
  }

  /// Returns a fixed time zone for the given ID, which must be "UTC" or "UTC[offset]" where "[offset]" can be parsed
  /// using the "general" offset pattern.
  ///
  /// [id]: ID
  ///
  /// Returns the parsed time zone, or null if the ID doesn't match.
  @internal
  static DateTimeZone? GetFixedZoneOrNull(String id) {
    if (!id.startsWith(DateTimeZone.UtcId)) {
      return null;
    }
    if (id == DateTimeZone.UtcId) {
      return DateTimeZone.Utc;
    }
    var parseResult = OffsetPattern.GeneralInvariant.Parse(id.substring(DateTimeZone.UtcId.length));
    return parseResult.Success ? DateTimeZone.ForOffset(parseResult.Value) : null;
  }

  /// Returns the fixed offset for this time zone.
  ///
  /// Returns the fixed offset for this time zone.
  nt.Offset get Offset => MaxOffset;

  /// Returns the name used for the zone interval for this time zone.
  ///
  /// Returns the name used for the zone interval for this time zone.
  String get Name => _interval.Name;

  /// Gets the zone interval for the given instant. This implementation always returns the same interval.
  @override
  ZoneInterval GetZoneInterval(Instant instant) => _interval;

  /// Override for efficiency: we know we'll always have an unambiguous mapping for any LocalDateTime.
  @override
  ZoneLocalMapping MapLocal(LocalDateTime localDateTime) =>
      ZoneLocalMapping.NewZoneLocalDateTimeEarlyIntervalLateIntervalCount(this, localDateTime, _interval, _interval, 1);

  /// Returns the offset from UTC, where a positive duration indicates that local time is later
  /// than UTC. In other words, local time = UTC + offset.
  ///
  /// [instant]: The instant for which to calculate the offset.
  ///
  /// Returns the offset from UTC at the specified instant.
  @override
  nt.Offset GetUtcOffset(Instant instant) => MaxOffset;

  /// Writes the time zone to the specified writer.
  ///
  /// [writer]: The writer.
  @internal
  void Write(IDateTimeZoneWriter writer) {
    // Dart: null safety checks writer.
    writer.WriteOffset(Offset);
    writer.WriteString(Name);
  }

  /// Reads a fixed time zone from the specified reader.
  ///
  /// [reader]: The reader.
  /// [id]: The id.
  ///
  /// Returns the fixed time zone.
  static DateTimeZone Read(IDateTimeZoneReader reader, String id) {
    // Dart: null safety checks reader and id.
    var offset = reader.ReadOffset();
    var name = reader.HasMoreData ? reader.ReadString() : id;
    return FixedDateTimeZone.NewIdOffsetName(id, offset, name);
  }

  /// Indicates whether this instance and a specified object are equal.
  ///
  /// [other]: Another object to compare to.
  ///
  /// Returns true if the specified value is a [FixedDateTimeZone] with the same name, ID and offset; otherwise, false.
  @override
  bool operator ==(Object other) => other is FixedDateTimeZone && Equals(other);

  bool Equals(FixedDateTimeZone? other) =>
      other != null &&
      Offset == other.Offset &&
      Id == other.Id &&
      Name == other.Name;

  /// Computes the hash code for this instance.
  ///
  /// Returns a 32-bit signed integer that is the hash code for this instance.
  @override
  int get hashCode => HashCodeHelper.HashStatic(Offset, Id, Name);

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() => Id;
}
