// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/Patterns/PatternFieldsExtensionsTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s `using static NodaTime.Text.Patterns.PatternFields` is the top-level constants below.

import 'package:noda_dart/src/Text/Patterns/PatternFields.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Text/PatternFieldsExtensionsTest.generated.dart' as scenarios;

const PatternFields Hours12 = PatternFields.Hours12;
const PatternFields Hours24 = PatternFields.Hours24;
const PatternFields Minutes = PatternFields.Minutes;
const PatternFields Seconds = PatternFields.Seconds;

void main() {
  port(scenarios.fixture, {
    'IsUsed_NoMatch': (args) {
      Assert.IsFalse((Hours12 | Minutes).HasAny(Hours24));
    },

    'IsUsed_SingleValueMatch': (args) {
      Assert.IsTrue(Hours24.HasAny(Hours24));
    },

    'IsFieldUsed_MultiValueMatch': (args) {
      Assert.IsTrue((Hours24 | Minutes).HasAny(Hours24));
    },

    'AllAreUsed_NoMatch': (args) {
      Assert.IsFalse((Hours12 | Minutes).HasAll(Hours24 | Seconds));
    },

    'AllAreUsed_PartialMatch': (args) {
      Assert.IsFalse((Hours12 | Minutes).HasAll(Hours12 | Seconds));
    },

    'AllAreUsed_CompleteMatch': (args) {
      Assert.IsTrue((Hours12 | Minutes).HasAll(Hours12 | Minutes));
    },

    'AllAreUsed_CompleteMatchWithMore': (args) {
      Assert.IsTrue((Hours24 | Minutes | Hours12).HasAll(Hours24 | Minutes));
    },
  });
}
