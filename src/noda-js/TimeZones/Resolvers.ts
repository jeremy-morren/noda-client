// Ported from NodaTime 3.3.7: src/NodaTime/TimeZones/Resolvers.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AmbiguousTimeException,
  Duration,
  OffsetDateTime,
  Preconditions,
  SkippedTimeException,
  ZonedDateTime,
} from "../internal.ts";
import type { AmbiguousTimeResolver, SkippedTimeResolver, ZoneLocalMappingResolver } from "../internal.ts";
import type { LocalDateTime } from "../internal.ts";
import { NewInvalidOperationException } from "../internal.ts";

let returnEarlier: AmbiguousTimeResolver | undefined;
let returnLater: AmbiguousTimeResolver | undefined;
let throwWhenAmbiguous: AmbiguousTimeResolver | undefined;
let returnEndOfIntervalBefore: SkippedTimeResolver | undefined;
let returnStartOfIntervalAfter: SkippedTimeResolver | undefined;
let returnForwardShifted: SkippedTimeResolver | undefined;
let throwWhenSkipped: SkippedTimeResolver | undefined;
let strictResolver: ZoneLocalMappingResolver | undefined;
let lenientResolver: ZoneLocalMappingResolver | undefined;

/**
 * Commonly-used implementations of the delegates used in resolving a {@link LocalDateTime} to a
 * {@link ZonedDateTime}, and a method to combine two "partial" resolvers into a full one.
 *
 * This class contains predefined implementations of {@link ZoneLocalMappingResolver},
 * {@link AmbiguousTimeResolver}, and {@link SkippedTimeResolver}, along with
 * {@link Resolvers.CreateMappingResolver}, which produces a `ZoneLocalMappingResolver` from instances of the
 * other two.
 *
 * All members of this class are thread-safe, as are the values returned by them.
 */
export class Resolvers {
  private constructor() {}

  /**
   * An {@link AmbiguousTimeResolver} which returns the earlier of the two matching times.
   */
  static get ReturnEarlier(): AmbiguousTimeResolver {
    return (returnEarlier ??= (earlier, _later) => earlier);
  }

  /**
   * An {@link AmbiguousTimeResolver} which returns the later of the two matching times.
   */
  static get ReturnLater(): AmbiguousTimeResolver {
    return (returnLater ??= (_earlier, later) => later);
  }

  /**
   * An {@link AmbiguousTimeResolver} which simply throws an {@link AmbiguousTimeException}.
   */
  static get ThrowWhenAmbiguous(): AmbiguousTimeResolver {
    return (throwWhenAmbiguous ??= (earlier, later) => {
      throw new AmbiguousTimeException(earlier, later);
    });
  }

  /**
   * A {@link SkippedTimeResolver} which returns the final tick of the time zone interval
   * before the "gap".
   */
  static get ReturnEndOfIntervalBefore(): SkippedTimeResolver {
    return (returnEndOfIntervalBefore ??= (local, zone, before, after) => {
      Preconditions.CheckNotNull(zone, "zone");
      Preconditions.CheckNotNull(before, "before");
      Preconditions.CheckNotNull(after, "after");
      // Given that there's a zone after before, it can't extend to the end of time.
      return new ZonedDateTime(before.End.Minus(Duration.Epsilon), zone, local.Calendar);
    });
  }

  /**
   * A {@link SkippedTimeResolver} which returns the first tick of the time zone interval
   * after the "gap".
   */
  static get ReturnStartOfIntervalAfter(): SkippedTimeResolver {
    return (returnStartOfIntervalAfter ??= (local, zone, before, after) => {
      Preconditions.CheckNotNull(zone, "zone");
      Preconditions.CheckNotNull(before, "before");
      Preconditions.CheckNotNull(after, "after");
      return new ZonedDateTime(after.Start, zone, local.Calendar);
    });
  }

  /**
   * A {@link SkippedTimeResolver} which shifts values in the "gap" forward by the duration
   * of the gap (which is usually 1 hour). This corresponds to the instant that would have occured,
   * had there not been a transition.
   */
  static get ReturnForwardShifted(): SkippedTimeResolver {
    return (returnForwardShifted ??= (local, zone, before, after) => {
      Preconditions.CheckNotNull(zone, "zone");
      Preconditions.CheckNotNull(before, "before");
      Preconditions.CheckNotNull(after, "after");
      return ZonedDateTime.NewOffsetDateTimeZone(new OffsetDateTime(local, before.WallOffset).WithOffset(after.WallOffset), zone);
    });
  }

  /**
   * A {@link SkippedTimeResolver} which simply throws a {@link SkippedTimeException}.
   */
  static get ThrowWhenSkipped(): SkippedTimeResolver {
    return (throwWhenSkipped ??= (local, zone, before, after) => {
      Preconditions.CheckNotNull(zone, "zone");
      Preconditions.CheckNotNull(before, "before");
      Preconditions.CheckNotNull(after, "after");
      throw new SkippedTimeException(local, zone);
    });
  }

  /**
   * A {@link ZoneLocalMappingResolver} which only ever succeeds in the (usual) case where the result
   * of the mapping is unambiguous.
   *
   * If the mapping is ambiguous or skipped, this throws {@link SkippedTimeException} or
   * {@link AmbiguousTimeException}, as appropriate. This resolver combines
   * {@link Resolvers.ThrowWhenAmbiguous} and {@link Resolvers.ThrowWhenSkipped}.
   *
   * @see DateTimeZone.AtStrictly
   */
  static get StrictResolver(): ZoneLocalMappingResolver {
    return (strictResolver ??= Resolvers.CreateMappingResolver(Resolvers.ThrowWhenAmbiguous, Resolvers.ThrowWhenSkipped));
  }

  /**
   * A {@link ZoneLocalMappingResolver} which never throws an exception due to ambiguity or skipped time.
   *
   * Ambiguity is handled by returning the earlier occurrence, and skipped times are shifted forward by the duration
   * of the gap. This resolver combines {@link Resolvers.ReturnEarlier} and {@link Resolvers.ReturnForwardShifted}.
   *
   * Note: The behavior of this resolver was changed in version 2.0 to fit the most commonly seen real-world
   * usage pattern.  Previous versions combined the {@link Resolvers.ReturnLater} and {@link Resolvers.ReturnStartOfIntervalAfter}
   * resolvers, which can still be used separately if desired.
   *
   * @see DateTimeZone.AtLeniently
   */
  static get LenientResolver(): ZoneLocalMappingResolver {
    return (lenientResolver ??= Resolvers.CreateMappingResolver(Resolvers.ReturnEarlier, Resolvers.ReturnForwardShifted));
  }

  /**
   * Combines an {@link AmbiguousTimeResolver} and a {@link SkippedTimeResolver} to create a
   * {@link ZoneLocalMappingResolver}.
   *
   * The `ZoneLocalMappingResolver` created by this method operates in the obvious way: unambiguous mappings
   * are returned directly, ambiguous mappings are delegated to the given `AmbiguousTimeResolver`, and
   * "skipped" mappings are delegated to the given `SkippedTimeResolver`.
   *
   * @param ambiguousTimeResolver Resolver to use for ambiguous mappings.
   * @param skippedTimeResolver Resolver to use for "skipped" mappings.
   * @returns The logical combination of the two resolvers.
   */
  static CreateMappingResolver(ambiguousTimeResolver: AmbiguousTimeResolver, skippedTimeResolver: SkippedTimeResolver): ZoneLocalMappingResolver {
    Preconditions.CheckNotNull(ambiguousTimeResolver, "ambiguousTimeResolver");
    Preconditions.CheckNotNull(skippedTimeResolver, "skippedTimeResolver");
    return mapping => {
      switch (Preconditions.CheckNotNull(mapping, "mapping").Count) {
        case 0: return skippedTimeResolver(mapping.LocalDateTime, mapping.Zone, mapping.EarlyInterval, mapping.LateInterval);
        case 1: return mapping.First();
        case 2: return ambiguousTimeResolver(mapping.First(), mapping.Last());
        default: throw NewInvalidOperationException("Mapping has count outside range 0-2; should not happen.");
      }
    };
  }
}
