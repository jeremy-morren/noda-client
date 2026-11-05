// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/ZoneTransitionTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneTransition constructor is the static factory NewInstantNameStandardOffsetSavings.

import { expect } from "vitest";
import { Duration, NodaConstants, Offset } from "../../../../src/noda-js/internal.ts";
import type { Instant } from "../../../../src/noda-js/internal.ts";
import { ZoneTransition } from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/ZoneTransitionTest.generated.ts";

/** C# `new ZoneTransition(instant, name, standardOffset, savings)`. */
function newZoneTransition(instant: Instant, name: string, standardOffset: Offset, savings: Offset): ZoneTransition {
  return ZoneTransition.NewInstantNameStandardOffsetSavings(instant, name, standardOffset, savings);
}

/** C# `NodaConstants.UnixEpoch + Duration.Epsilon`. */
function afterEpoch(): Instant {
  return NodaConstants.UnixEpoch.Plus(Duration.Epsilon);
}

port(fixture, {
  Construct_NullName_Exception() {
    assertThrows("ArgumentNullException", () => newZoneTransition(NodaConstants.UnixEpoch, null!, Offset.Zero, Offset.Zero));
  },

  Construct_Normal() {
    const name = "abc";
    const actual = newZoneTransition(NodaConstants.UnixEpoch, name, Offset.Zero, Offset.Zero);
    assertNodaEqual(actual.Instant, NodaConstants.UnixEpoch, "Instant");
    assertNodaEqual(actual.Name, name, "GetName");
    assertNodaEqual(actual.WallOffset, Offset.Zero, "WallOffset");
    assertNodaEqual(actual.StandardOffset, Offset.Zero, "StandardOffset");
  },

  IsTransitionFrom_null_throws() {
    const value = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    assertThrows("ArgumentNullException", () => value.IsTransitionFrom(null!));
  },

  IsTransitionFrom_identity_false() {
    const value = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    expect(value.IsTransitionFrom(value)).toBe(false);
  },

  IsTransitionFrom_equalObject_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_unequalStandardOffset_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.MaxValue, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_unequalSavings_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.MaxValue);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_unequalName_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "qwe", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_earlierInstant_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_earlierInstantAndUnequalStandardOffset_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(afterEpoch(), "abc", Offset.MaxValue, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_earlierInstantAndUnequalSavings_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.MaxValue);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_earlierInstantAndUnequalName_false() {
    const newValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(afterEpoch(), "qwe", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_laterInstant_false() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(false);
  },

  IsTransitionFrom_laterInstantAndUnequalStandardOffset_true() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.MaxValue, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(true);
  },

  IsTransitionFrom_laterInstantAndUnequalSavings_true() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.MaxValue);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(true);
  },

  // We view any change as a time zone transition, even if it doesn't affect name or wall time.
  // As an example, in 1968 the UK changed from BST (British Summer Time, standard 0, daylight 1)
  // to BST (British Standard Time, standard 1, daylight 0). Regarding this as a transition is
  // cleaner than ignoring it.
  IsTransitionFrom_laterInstantAndEqualButOppositeStandardAndSavings_true() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.FromHours(1), Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "abc", Offset.Zero, Offset.FromHours(1));
    expect(newValue.IsTransitionFrom(oldValue)).toBe(true);
  },

  IsTransitionFrom_laterInstantAndUnequalName_true() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "qwe", Offset.Zero, Offset.Zero);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(true);
  },

  IsTransitionFrom_laterInstantAndUnequalNameAndSavings_true() {
    const newValue = newZoneTransition(afterEpoch(), "abc", Offset.Zero, Offset.Zero);
    const oldValue = newZoneTransition(NodaConstants.UnixEpoch, "qwe", Offset.Zero, Offset.MaxValue);
    expect(newValue.IsTransitionFrom(oldValue)).toBe(true);
  },
});
