// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/PrecalculatedDateTimeZone.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../DateTimeZone.dart';
import '../Instant.dart';
import '../Offset.dart';
import '../Utility/Preconditions.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'IZoneIntervalMap.dart';
import 'StandardDaylightAlternatingMap.dart';
import 'ZoneInterval.dart';

/// Most time zones have a relatively small set of transitions at their start until they finally
/// settle down to either a fixed time zone or a daylight savings time zone. This provides the
/// container for the initial zone intervals and a pointer to the time zone that handles all of
/// the rest until the end of time.
@internal
final class PrecalculatedDateTimeZone extends DateTimeZone {
  final List<ZoneInterval> _periods;
  final IZoneIntervalMap? _tailZone;

  /// The first instant covered by the tail zone, or Instant.AfterMaxValue if there's no tail zone.
  final Instant _tailZoneStart;
  final ZoneInterval? _firstTailZoneInterval;

  /// Initializes a new instance of the [PrecalculatedDateTimeZone] class.
  ///
  /// [id]: The id.
  /// [intervals]: The intervals before the tail zone.
  /// [tailZone]: The tail zone - which can be any IZoneIntervalMap for normal operation,
  /// but must be a StandardDaylightAlternatingMap if the result is to be serialized.
  @internal // C#: [VisibleForTesting], documentation only (the tzdb compiler calls it too).
  PrecalculatedDateTimeZone.NewIdIntervalsTailZone(String id, List<ZoneInterval> intervals, IZoneIntervalMap? tailZone)
      // Dart: through a private constructor, so that the offsets are computed (and the intervals checked) before the
      // fields are initialized, as C# evaluates the base constructor's arguments first.
      : this._NewIdIntervalsTailZoneMinOffsetMaxOffset(id, intervals, tailZone,
            _ComputeOffset(intervals, tailZone, Offset.Min),
            _ComputeOffset(intervals, tailZone, Offset.Max));

  PrecalculatedDateTimeZone._NewIdIntervalsTailZoneMinOffsetMaxOffset(
      String id, List<ZoneInterval> intervals, IZoneIntervalMap? tailZone, Offset minOffset, Offset maxOffset)
      : _periods = intervals,
        _tailZone = tailZone,
        _tailZoneStart = intervals[intervals.length - 1].RawEnd, // We want this to be AfterMaxValue for tail-less zones.
        // Cache a "clamped" zone interval for use at the start of the tail zone.
        _firstTailZoneInterval = tailZone
            ?.GetZoneInterval(intervals[intervals.length - 1].RawEnd)
            .WithStart(intervals[intervals.length - 1].RawEnd),
        super(id, false, minOffset, maxOffset) {
    ValidatePeriods(intervals, tailZone);
  }

  /// Validates that all the periods before the tail zone make sense. We have to start at the beginning of time,
  /// and then have adjoining periods. This is only called in the constructors.
  ///
  /// This is only called from the constructors, but is internal to make it easier to test.
  ///
  /// Throws [ArgumentError] if the periods specified are invalid.
  @internal // C#: [VisibleForTesting], documentation only (the tzdb compiler calls it too).
  static void ValidatePeriods(List<ZoneInterval> periods, IZoneIntervalMap? tailZone) {
    Preconditions.CheckArgument(periods.isNotEmpty, 'periods', 'No periods specified in precalculated time zone');
    Preconditions.CheckArgument(!periods[0].HasStart, 'periods', 'Periods in precalculated time zone must start with the beginning of time');
    for (int i = 0; i < periods.length - 1; i++) {
      // Safe to use End here: there can't be a period *after* an endless one. Likewise it's safe to use Start on the next
      // period, as there can't be a period *before* one which goes back to the start of time.
      Preconditions.CheckArgument(periods[i].End == periods[i + 1].Start, 'periods', 'Non-adjoining ZoneIntervals for precalculated time zone');
    }
    Preconditions.CheckArgument(tailZone != null || periods[periods.length - 1].RawEnd == Instant.AfterMaxValue, 'tailZone', "Null tail zone given but periods don't cover all of time");
  }

  /// Gets the zone offset period for the given instant.
  ///
  /// [instant]: The Instant to find.
  ///
  /// Returns the ZoneInterval including the given instant.
  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    if (_tailZone != null && instant >= _tailZoneStart) {
      // Clamp the tail zone interval to start at the end of our final period, if necessary, so that the
      // join is seamless.
      ZoneInterval intervalFromTailZone = _tailZone.GetZoneInterval(instant);
      return intervalFromTailZone.RawStart < _tailZoneStart ? _firstTailZoneInterval! : intervalFromTailZone;
    }

    int lower = 0; // Inclusive
    int upper = _periods.length; // Exclusive

    while (lower < upper) {
      int current = (lower + upper) ~/ 2;
      var candidate = _periods[current];
      if (candidate.RawStart > instant) {
        upper = current;
      }
      // Safe to use RawEnd, as it's just for the comparison.
      else if (candidate.RawEnd <= instant) {
        lower = current + 1;
      } else {
        return candidate;
      }
    }
    // Note: this would indicate a bug. The time zone is meant to cover the whole of time.
    throw StateError('Instant $instant did not exist in time zone $Id');
  }

  // #region I/O
  // Note: used in TzdbCompiler.
  /// Writes the time zone to the specified writer.
  ///
  /// [writer]: The writer to write to.
  @internal
  void Write(IDateTimeZoneWriter writer) {
    // Dart: null safety checks writer.

    // We used to create a pool of strings just for this zone. This was more efficient
    // for some zones, as it meant that each string would be written out with just a single
    // byte after the pooling. Optimizing the string pool globally instead allows for
    // roughly the same efficiency, and simpler code here.
    writer.WriteCount(_periods.length);
    Instant? previous;
    for (var period in _periods) {
      writer.WriteZoneIntervalTransition(previous, previous = period.RawStart);
      writer.WriteString(period.Name);
      writer.WriteOffset(period.WallOffset);
      writer.WriteOffset(period.Savings);
    }
    writer.WriteZoneIntervalTransition(previous, _tailZoneStart);
    // We could just check whether we've got to the end of the stream, but this
    // feels slightly safer.
    writer.WriteByte(_tailZone == null ? 0 : 1);
    if (_tailZone != null) {
      // This is the only kind of zone we support in the new format. Enforce that...
      var tailDstZone = _tailZone as StandardDaylightAlternatingMap;
      tailDstZone.Write(writer);
    }
  }

  /// Reads a time zone from the specified reader.
  ///
  /// [reader]: The reader.
  /// [id]: The id.
  ///
  /// Returns the time zone.
  @internal
  static DateTimeZone Read(IDateTimeZoneReader reader, String id) {
    // Dart: null safety checks reader and id.
    int size = reader.ReadCount();
    // Dart: a list filled in order (C#: new ZoneInterval[size]).
    var periods = <ZoneInterval>[];
    // It's not entirely clear why we don't just assume that the first zone interval always starts at Instant.BeforeMinValue
    // (given that we check that later) but we don't... and changing that now could cause compatibility issues.
    var start = reader.ReadZoneIntervalTransition(null);
    for (int i = 0; i < size; i++) {
      var name = reader.ReadString();
      var offset = reader.ReadOffset();
      var savings = reader.ReadOffset();
      var nextStart = reader.ReadZoneIntervalTransition(start);
      periods.add(ZoneInterval.NewNameStartEndWallOffsetSavings(name, start, nextStart, offset, savings));
      start = nextStart;
    }
    var tailZone = reader.ReadByte() == 1 ? StandardDaylightAlternatingMap.Read(reader) : null;
    return PrecalculatedDateTimeZone.NewIdIntervalsTailZone(id, periods, tailZone);
  }
  // #endregion // I/O

  // #region Offset computation for constructors
  // Essentially Func<Offset, Offset, Offset>
  // (C#: the delegates OffsetAggregator and OffsetExtractor<in T>.)

  // Reasonably simple way of computing the maximum/minimum offset
  // from either periods or transitions, with or without a tail zone.
  static Offset _ComputeOffset(List<ZoneInterval> intervals,
      IZoneIntervalMap? tailZone,
      _OffsetAggregator aggregator) {
    // Dart: null safety checks intervals.
    Preconditions.CheckArgument(intervals.isNotEmpty, 'intervals', 'No intervals specified');
    Offset ret = intervals[0].WallOffset;
    for (int i = 1; i < intervals.length; i++) {
      ret = aggregator(ret, intervals[i].WallOffset);
    }
    if (tailZone != null) {
      // Effectively a shortcut for picking either tailZone.MinOffset or
      // tailZone.MaxOffset
      Offset bestFromZone = aggregator(tailZone.MinOffset, tailZone.MaxOffset);
      ret = aggregator(ret, bestFromZone);
    }
    return ret;
  }
  // #endregion
}

// Essentially Func<Offset, Offset, Offset>
typedef _OffsetAggregator = Offset Function(Offset x, Offset y);
