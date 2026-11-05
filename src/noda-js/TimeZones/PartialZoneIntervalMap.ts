// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/PartialZoneIntervalMap.cs
// Copyright 2015 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Duration, Instant, Offset, Preconditions, SingleZoneIntervalMap, ZoneInterval } from "../internal.ts";
import type { IZoneIntervalMap } from "../internal.ts";
import { NewInvalidOperationException } from "../internal.ts";

/**
 * Like ZoneIntervalMap, representing just part of the time line. The intervals returned by this map
 * are clamped to the portion of the time line being represented, to make it easier to work with.
 * @internal
 */
export class PartialZoneIntervalMap {
  // noda-js: private in NodaTime; not private here, as the nested CombinedPartialZoneIntervalMap
  // (a separate class in TypeScript) reads it.
  /** @internal */
  readonly _map: IZoneIntervalMap;

  /**
   * Start of the interval during which this map is valid.
   */
  readonly Start: Instant;

  /**
   * End (exclusive) of the interval during which this map is valid.
   */
  readonly End: Instant;

  // noda-js: the C# constructor is internal; the class itself is internal, so the constructor is kept
  // alongside the mechanical factory.
  constructor(start: Instant, end: Instant, map: IZoneIntervalMap) {
    // Allowing empty maps makes life simpler.
    Preconditions.DebugCheckArgument(start.CompareTo(end) <= 0, "end",
      "Invalid start/end combination: {0} - {1}", start, end);
    this.Start = start;
    this.End = end;
    this._map = map;
  }

  static NewStartEndMap(start: Instant, end: Instant, map: IZoneIntervalMap): PartialZoneIntervalMap {
    return new PartialZoneIntervalMap(start, end, map);
  }

  /**
   * Builds a PartialZoneIntervalMap for a single zone interval with the given name, start, end, wall offset and daylight savings.
   */
  static ForZoneInterval(name: string, start: Instant, end: Instant, wallOffset: Offset, savings: Offset): PartialZoneIntervalMap;
  /**
   * Builds a PartialZoneIntervalMap wrapping the given zone interval, taking its start and end as the start and end of
   * the portion of the time line handled by the partial map.
   */
  static ForZoneInterval(interval: ZoneInterval): PartialZoneIntervalMap;
  static ForZoneInterval(nameOrInterval: string | ZoneInterval, start?: Instant, end?: Instant, wallOffset?: Offset, savings?: Offset): PartialZoneIntervalMap {
    if (typeof nameOrInterval === "string") {
      return PartialZoneIntervalMap.ForZoneInterval(new ZoneInterval(nameOrInterval, start!, end!, wallOffset!, savings!));
    }
    const interval = nameOrInterval;
    return new PartialZoneIntervalMap(interval.RawStart, interval.RawEnd, new SingleZoneIntervalMap(interval));
  }

  GetZoneInterval(instant: Instant): ZoneInterval {
    Preconditions.DebugCheckArgument(instant.CompareTo(this.Start) >= 0 && instant.CompareTo(this.End) < 0, "instant",
      "Value {0} was not in the range [{1}, {2})", instant, this.Start, this.End);
    let interval = this._map.GetZoneInterval(instant);
    // Clamp the interval for the sake of sanity. Checking this every time isn't very efficient,
    // but we're not expecting this to be called too often, due to caching.
    if (interval.RawStart.CompareTo(this.Start) < 0) {
      interval = interval.WithStart(this.Start);
    }
    if (interval.RawEnd.CompareTo(this.End) > 0) {
      interval = interval.WithEnd(this.End);
    }
    return interval;
  }

  /**
   * Returns true if this map only contains a single interval; that is, if the first interval includes the end of the map.
   */
  private get IsSingleInterval(): boolean {
    return this._map.GetZoneInterval(this.Start).RawEnd.CompareTo(this.End) >= 0;
  }

  /**
   * Returns a partial zone interval map equivalent to this one, but with the given start point.
   */
  WithStart(start: Instant): PartialZoneIntervalMap {
    return new PartialZoneIntervalMap(start, this.End, this._map);
  }

  /**
   * Returns a partial zone interval map equivalent to this one, but with the given end point.
   */
  WithEnd(end: Instant): PartialZoneIntervalMap {
    return new PartialZoneIntervalMap(this.Start, end, this._map);
  }

  /**
   * Converts a sequence of PartialZoneIntervalMaps covering the whole time line into an IZoneIntervalMap.
   * The partial maps are expected to be in order, with the start of the first map being Instant.BeforeMinValue,
   * the end of the last map being Instant.AfterMaxValue, and each adjacent pair of maps abutting (i.e. current.End == next.Start).
   * Zone intervals belonging to abutting maps but which are equivalent in terms of offset and name
   * are coalesced in the resulting map.
   */
  static ConvertToFullMap(maps: Iterable<PartialZoneIntervalMap>): IZoneIntervalMap {
    const coalescedMaps: PartialZoneIntervalMap[] = [];
    let current: PartialZoneIntervalMap | null = null;
    for (const next of maps) {
      if (current === null) {
        current = next;
        Preconditions.DebugCheckArgument(current.Start.Equals(Instant.BeforeMinValue), "maps", "First partial map must start at the beginning of time. Actual start: {0:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}",
          current.Start);
        continue;
      }
      Preconditions.DebugCheckArgument(current.End.Equals(next.Start), "maps",
        "Maps must abut: {0:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}Z != {1:uuuu-MM-dd'T'HH:mm:ss.FFFFFFF}Z", current.End, next.Start);

      if (next.Start.Equals(next.End)) {
        continue;
      }

      const lastIntervalOfCurrent = current.GetZoneInterval(current.End.Minus(Duration.Epsilon));
      const firstIntervalOfNext = next.GetZoneInterval(next.Start);

      if (!lastIntervalOfCurrent.EqualIgnoreBounds(firstIntervalOfNext)) {
        // There's a genuine transition at the boundary of the partial maps. Add the current one, and move on
        // to the next.
        coalescedMaps.push(current);
        current = next;
      } else {
        // The boundary belongs to a single zone interval crossing the two maps. Some coalescing to do.

        // If both the current and the next map are single zone interval maps, we can just make the current one
        // go on until the end of the next one instead.
        if (current.IsSingleInterval && next.IsSingleInterval) {
          current = PartialZoneIntervalMap.ForZoneInterval(lastIntervalOfCurrent.WithEnd(next.End));
        } else if (current.IsSingleInterval) {
          // The next map has at least one transition. Add a single new map for the portion of time from the
          // start of current to the first transition in next, then continue on with the next map, starting at the first transition.
          coalescedMaps.push(PartialZoneIntervalMap.ForZoneInterval(lastIntervalOfCurrent.WithEnd(firstIntervalOfNext.End)));
          current = next.WithStart(firstIntervalOfNext.End);
        } else if (next.IsSingleInterval) {
          // The current map as at least one transition. Add a version of that, clamped to end at the final transition,
          // then continue with a new map which takes in the last portion of the current and the whole of next.
          coalescedMaps.push(current.WithEnd(lastIntervalOfCurrent.Start));
          current = PartialZoneIntervalMap.ForZoneInterval(firstIntervalOfNext.WithStart(lastIntervalOfCurrent.Start));
        } else {
          // Transitions in both maps. Add the part of current before the last transition, and a single map containing
          // the coalesced interval across the boundary, then continue with the next map, starting at the first transition.
          coalescedMaps.push(current.WithEnd(lastIntervalOfCurrent.Start));
          coalescedMaps.push(PartialZoneIntervalMap.ForZoneInterval(lastIntervalOfCurrent.WithEnd(firstIntervalOfNext.End)));
          current = next.WithStart(firstIntervalOfNext.End);
        }
      }
    }
    Preconditions.DebugCheckArgument(current !== null, "maps", "Collection of maps must not be empty");
    Preconditions.DebugCheckArgument(current!.End.Equals(Instant.AfterMaxValue), "maps", "Collection of maps must end at the end of time");

    // We're left with a map extending to the end of time, which couldn't have been coalesced with its predecessors.
    coalescedMaps.push(current!);
    return new PartialZoneIntervalMapCombinedPartialZoneIntervalMap(coalescedMaps);
  }
}

/**
 * Implementation of IZoneIntervalMap used by ConvertToFullMap
 */
class PartialZoneIntervalMapCombinedPartialZoneIntervalMap implements IZoneIntervalMap {
  private readonly _partialMaps: readonly PartialZoneIntervalMap[];

  readonly MinOffset: Offset;
  readonly MaxOffset: Offset;

  constructor(partialMaps: readonly PartialZoneIntervalMap[]) {
    this._partialMaps = partialMaps;
    this.MinOffset = partialMaps.reduce((min, partialMap) => Offset.Min(min, partialMap._map.MinOffset), Offset.MaxValue);
    this.MaxOffset = partialMaps.reduce((max, partialMap) => Offset.Max(max, partialMap._map.MaxOffset), Offset.MinValue);
  }

  GetZoneInterval(instant: Instant): ZoneInterval {
    // We assume the maps are ordered, and start with "beginning of time"
    // which means we only need to find the first partial map which ends after
    // the instant we're interested in. This is just a linear search - a binary search
    // would be feasible, but we're not expecting very many entries.
    for (const partialMap of this._partialMaps) {
      if (instant.CompareTo(partialMap.End) < 0) {
        return partialMap.GetZoneInterval(instant);
      }
    }
    throw NewInvalidOperationException("Instant not contained in any map");
  }
}
