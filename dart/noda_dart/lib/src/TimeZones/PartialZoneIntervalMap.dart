// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/PartialZoneIntervalMap.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Duration.dart';
import '../Instant.dart';
import '../Offset.dart';
import '../Utility/Preconditions.dart';
import 'IZoneIntervalMap.dart';
import 'SingleZoneIntervalMap.dart';
import 'ZoneInterval.dart';

/// Like ZoneIntervalMap, representing just part of the time line. The intervals returned by this map
/// are clamped to the portion of the time line being represented, to make it easier to work with.
@internal
final class PartialZoneIntervalMap {
  final IZoneIntervalMap _map;

  /// Start of the interval during which this map is valid.
  @internal
  final Instant Start;

  /// End (exclusive) of the interval during which this map is valid.
  @internal
  final Instant End;

  @internal
  PartialZoneIntervalMap.NewStartEndMap(Instant start, Instant end, IZoneIntervalMap map)
      : Start = start,
        End = end,
        _map = map {
    // Allowing empty maps makes life simpler.
    Preconditions.DebugCheckArgument(start <= end, 'end',
        'Invalid start/end combination: {0} - {1}', [start, end]);
  }

  /// Builds a PartialZoneIntervalMap for a single zone interval with the given name, start, end, wall offset and daylight savings.
  @internal
  static PartialZoneIntervalMap ForZoneInterval(String name, Instant start, Instant end, Offset wallOffset, Offset savings) =>
      ForZoneIntervalZoneInterval(ZoneInterval.NewNameStartEndWallOffsetSavings(name, start, end, wallOffset, savings));

  /// Builds a PartialZoneIntervalMap wrapping the given zone interval, taking its start and end as the start and end of
  /// the portion of the time line handled by the partial map.
  @internal
  static PartialZoneIntervalMap ForZoneIntervalZoneInterval(ZoneInterval interval) =>
      PartialZoneIntervalMap.NewStartEndMap(interval.RawStart, interval.RawEnd, SingleZoneIntervalMap.NewInterval(interval));

  @internal
  ZoneInterval GetZoneInterval(Instant instant) {
    Preconditions.DebugCheckArgument(instant >= Start && instant < End, 'instant',
        'Value {0} was not in the range [{1}, {2})', [instant, Start, End]);
    var interval = _map.GetZoneInterval(instant);
    // Clamp the interval for the sake of sanity. Checking this every time isn't very efficient,
    // but we're not expecting this to be called too often, due to caching.
    if (interval.RawStart < Start) {
      interval = interval.WithStart(Start);
    }
    if (interval.RawEnd > End) {
      interval = interval.WithEnd(End);
    }
    return interval;
  }

  /// Returns true if this map only contains a single interval; that is, if the first interval includes the end of the map.
  bool get _IsSingleInterval => _map.GetZoneInterval(Start).RawEnd >= End;

  /// Returns a partial zone interval map equivalent to this one, but with the given start point.
  @internal
  PartialZoneIntervalMap WithStart(Instant start) {
    return PartialZoneIntervalMap.NewStartEndMap(start, End, _map);
  }

  /// Returns a partial zone interval map equivalent to this one, but with the given end point.
  @internal
  PartialZoneIntervalMap WithEnd(Instant end) {
    return PartialZoneIntervalMap.NewStartEndMap(Start, end, _map);
  }

  /// Converts a sequence of PartialZoneIntervalMaps covering the whole time line into an IZoneIntervalMap.
  /// The partial maps are expected to be in order, with the start of the first map being Instant.BeforeMinValue,
  /// the end of the last map being Instant.AfterMaxValue, and each adjacent pair of maps abutting (i.e. current.End == next.Start).
  /// Zone intervals belonging to abutting maps but which are equivalent in terms of offset and name
  /// are coalesced in the resulting map.
  @internal
  static IZoneIntervalMap ConvertToFullMap(Iterable<PartialZoneIntervalMap> maps) {
    var coalescedMaps = <PartialZoneIntervalMap>[];
    PartialZoneIntervalMap? current;
    for (var next in maps) {
      if (current == null) {
        current = next;
        Preconditions.DebugCheckArgument(current.Start == Instant.BeforeMinValue, 'maps', "First partial map must start at the beginning of time. Actual start: {0:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}",
            [current.Start]);
        continue;
      }
      Preconditions.DebugCheckArgument(current.End == next.Start, 'maps',
          "Maps must abut: {0:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}Z != {1:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}Z", [current.End, next.Start]);

      if (next.Start == next.End) {
        continue;
      }

      var lastIntervalOfCurrent = current.GetZoneInterval(current.End.MinusDuration(Duration.Epsilon));
      var firstIntervalOfNext = next.GetZoneInterval(next.Start);

      if (!lastIntervalOfCurrent.EqualIgnoreBounds(firstIntervalOfNext)) {
        // There's a genuine transition at the boundary of the partial maps. Add the current one, and move on
        // to the next.
        coalescedMaps.add(current);
        current = next;
      } else {
        // The boundary belongs to a single zone interval crossing the two maps. Some coalescing to do.

        // If both the current and the next map are single zone interval maps, we can just make the current one
        // go on until the end of the next one instead.
        if (current._IsSingleInterval && next._IsSingleInterval) {
          current = ForZoneIntervalZoneInterval(lastIntervalOfCurrent.WithEnd(next.End));
        } else if (current._IsSingleInterval) {
          // The next map has at least one transition. Add a single new map for the portion of time from the
          // start of current to the first transition in next, then continue on with the next map, starting at the first transition.
          coalescedMaps.add(ForZoneIntervalZoneInterval(lastIntervalOfCurrent.WithEnd(firstIntervalOfNext.End)));
          current = next.WithStart(firstIntervalOfNext.End);
        } else if (next._IsSingleInterval) {
          // The current map as at least one transition. Add a version of that, clamped to end at the final transition,
          // then continue with a new map which takes in the last portion of the current and the whole of next.
          coalescedMaps.add(current.WithEnd(lastIntervalOfCurrent.Start));
          current = ForZoneIntervalZoneInterval(firstIntervalOfNext.WithStart(lastIntervalOfCurrent.Start));
        } else {
          // Transitions in both maps. Add the part of current before the last transition, and a single map containing
          // the coalesced interval across the boundary, then continue with the next map, starting at the first transition.
          coalescedMaps.add(current.WithEnd(lastIntervalOfCurrent.Start));
          coalescedMaps.add(ForZoneIntervalZoneInterval(lastIntervalOfCurrent.WithEnd(firstIntervalOfNext.End)));
          current = next.WithStart(firstIntervalOfNext.End);
        }
      }
    }
    Preconditions.DebugCheckArgument(current != null, 'maps', 'Collection of maps must not be empty');
    Preconditions.DebugCheckArgument(current!.End == Instant.AfterMaxValue, 'maps', 'Collection of maps must end at the end of time');

    // We're left with a map extending to the end of time, which couldn't have been coalesced with its predecessors.
    coalescedMaps.add(current);
    return _PartialZoneIntervalMapCombinedPartialZoneIntervalMap._NewPartialMaps(List<PartialZoneIntervalMap>.of(coalescedMaps));
  }
}

/// Implementation of IZoneIntervalMap used by ConvertToFullMap
final class _PartialZoneIntervalMapCombinedPartialZoneIntervalMap implements IZoneIntervalMap {
  final List<PartialZoneIntervalMap> _partialMaps;

  @override
  final Offset MinOffset;
  @override
  final Offset MaxOffset;

  _PartialZoneIntervalMapCombinedPartialZoneIntervalMap._NewPartialMaps(List<PartialZoneIntervalMap> partialMaps)
      : _partialMaps = partialMaps,
        MinOffset = partialMaps.fold(Offset.MaxValue, (min, partialMap) => Offset.Min(min, partialMap._map.MinOffset)),
        MaxOffset = partialMaps.fold(Offset.MinValue, (max, partialMap) => Offset.Max(max, partialMap._map.MaxOffset));

  @override
  ZoneInterval GetZoneInterval(Instant instant) {
    // We assume the maps are ordered, and start with "beginning of time"
    // which means we only need to find the first partial map which ends after
    // the instant we're interested in. This is just a linear search - a binary search
    // would be feasible, but we're not expecting very many entries.
    for (var partialMap in _partialMaps) {
      if (instant < partialMap.End) {
        return partialMap.GetZoneInterval(instant);
      }
    }
    throw StateError('Instant not contained in any map');
  }
}
