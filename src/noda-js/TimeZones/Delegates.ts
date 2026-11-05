// Ported from NodaTime 3.3.0: src/NodaTime/TimeZones/Delegates.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import type { DateTimeZone, LocalDateTime, ZonedDateTime, ZoneInterval, ZoneLocalMapping } from "../internal.ts";
import type { AmbiguousTimeError, Resolvers, SkippedTimeError } from "../internal.ts";

// Delegates used for mapping local date/time values to ZonedDateTime.

/**
 * Chooses between two {@link ZonedDateTime} values that resolve to the same {@link LocalDateTime}.
 *
 * This delegate is used by {@link Resolvers.CreateMappingResolver} when handling an ambiguous local time,
 * due to clocks moving backward in a time zone transition (usually due to an autumnal daylight saving transition).
 *
 * The returned value should be one of the two parameter values, based on the policy of the specific
 * implementation. Alternatively, it can throw an {@link AmbiguousTimeError} to implement a policy of
 * "reject ambiguous times."
 *
 * See the {@link Resolvers} class for predefined implementations.
 *
 * Implementations of this delegate can reasonably
 * assume that the target local date and time really is ambiguous; the behaviour when the local date and time
 * can be unambiguously mapped into the target time zone (or when it's skipped) is undefined.
 *
 * @param earlier The earlier of the ambiguous matches for the original local date and time
 * @param later The later of the ambiguous matches for the original local date and time
 * @throws {AmbiguousTimeError} The implementation rejects requests to map ambiguous times.
 * @returns A {@link ZonedDateTime} in the target time zone; typically, one of the two input parameters.
 */
export type AmbiguousTimeResolver = (earlier: ZonedDateTime, later: ZonedDateTime) => ZonedDateTime;

/**
 * Resolves a {@link LocalDateTime} to a {@link ZonedDateTime} in the situation
 * where the requested local time does not exist in the target time zone.
 *
 * This delegate is used by {@link Resolvers.CreateMappingResolver} when handling the situation where the
 * requested local time does not exist, due to clocks moving forward in a time zone transition (usually due to a
 * spring daylight saving transition).
 *
 * The returned value will necessarily represent a different local date and time to the target one, but
 * the exact form of mapping is up to the delegate implementation. For example, it could return a value
 * as close to the target local date and time as possible, or the time immediately after the transition.
 * Alternatively, it can throw a {@link SkippedTimeError} to implement a policy of "reject
 * skipped times."
 *
 * See the {@link Resolvers} class for predefined implementations.
 *
 * Implementations of this delegate can reasonably
 * assume that the target local date and time really is skipped; the behaviour when the local date and time
 * can be directly mapped into the target time zone is undefined.
 *
 * @param localDateTime The local date and time to map to the given time zone
 * @param zone The target time zone
 * @param intervalBefore The zone interval directly before the target local date and time would have occurred
 * @param intervalAfter The zone interval directly after the target local date and time would have occurred
 * @throws {SkippedTimeError} The implementation rejects requests to map skipped times.
 * @returns A {@link ZonedDateTime} in the target time zone.
 */
export type SkippedTimeResolver = (localDateTime: LocalDateTime, zone: DateTimeZone,
  intervalBefore: ZoneInterval, intervalAfter: ZoneInterval) => ZonedDateTime;

/**
 * Resolves the result of attempting to map a local date and time to a target time zone.
 *
 * This delegate is consumed by {@link LocalDateTime.InZone} and {@link DateTimeZone.ResolveLocal},
 * among others. It provides the strategy for converting a {@link ZoneLocalMapping} (the result of attempting
 * to map a local date and time to a target time zone) to a {@link ZonedDateTime}.
 *
 * See the {@link Resolvers} class for predefined implementations and a way of combining
 * separate {@link SkippedTimeResolver} and {@link AmbiguousTimeResolver} values.
 *
 * @param mapping The intermediate result of mapping a local time to a target time zone.
 * @throws {AmbiguousTimeError} The implementation rejects requests to map ambiguous times.
 * @throws {SkippedTimeError} The implementation rejects requests to map skipped times.
 * @returns A {@link ZonedDateTime} in the target time zone.
 */
export type ZoneLocalMappingResolver = (mapping: ZoneLocalMapping) => ZonedDateTime;
