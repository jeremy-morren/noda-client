// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/ZoneTransitionTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the internal ZoneTransition constructor is ZoneTransition.NewInstantNameStandardOffsetSavings.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/ZoneTransition.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/ZoneTransitionTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Construct_Normal': (args) {
      const String name = 'abc';
      var actual = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, name, Offset.Zero, Offset.Zero);
      Assert.AreEqual(NodaConstants.UnixEpoch, actual.Instant, 'Instant');
      Assert.AreEqual(name, actual.Name, 'GetName');
      Assert.AreEqual(Offset.Zero, actual.WallOffset, 'WallOffset');
      Assert.AreEqual(Offset.Zero, actual.StandardOffset, 'StandardOffset');
    },

    'IsTransitionFrom_identity_false': (args) {
      var value = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      Assert.False(value.IsTransitionFrom(value));
    },

    'IsTransitionFrom_equalObject_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_unequalStandardOffset_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.MaxValue, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_unequalSavings_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.MaxValue);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_unequalName_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'qwe', Offset.Zero, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_earlierInstant_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_earlierInstantAndUnequalStandardOffset_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.MaxValue, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_earlierInstantAndUnequalSavings_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.MaxValue);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_earlierInstantAndUnequalName_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'qwe', Offset.Zero, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_laterInstant_false': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.Zero);
      Assert.False(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_laterInstantAndUnequalStandardOffset_true': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.MaxValue, Offset.Zero);
      Assert.True(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_laterInstantAndUnequalSavings_true': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.MaxValue);
      Assert.True(newValue.IsTransitionFrom(oldValue));
    },

    // We view any change as a time zone transition, even if it doesn't affect name or wall time.
    // As an example, in 1968 the UK changed from BST (British Summer Time, standard 0, daylight 1)
    // to BST (British Standard Time, standard 1, daylight 0). Regarding this as a transition is
    // cleaner than ignoring it.
    'IsTransitionFrom_laterInstantAndEqualButOppositeStandardAndSavings_true': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.FromHours(1), Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'abc', Offset.Zero, Offset.FromHours(1));
      Assert.True(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_laterInstantAndUnequalName_true': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      var oldValue = ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'qwe', Offset.Zero, Offset.Zero);
      Assert.True(newValue.IsTransitionFrom(oldValue));
    },

    'IsTransitionFrom_laterInstantAndUnequalNameAndSavings_true': (args) {
      var newValue = ZoneTransition.NewInstantNameStandardOffsetSavings(
          NodaConstants.UnixEpoch + Duration.Epsilon, 'abc', Offset.Zero, Offset.Zero);
      var oldValue =
          ZoneTransition.NewInstantNameStandardOffsetSavings(NodaConstants.UnixEpoch, 'qwe', Offset.Zero, Offset.MaxValue);
      Assert.True(newValue.IsTransitionFrom(oldValue));
    },
  }, skip: {
    'Construct_NullName_Exception': SkipReasons.NullSafety,
    'IsTransitionFrom_null_throws': SkipReasons.NullSafety,
  });
}
