// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/CompositePatternBuilderPatternTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s collection initializers ({ { pattern, predicate }, ... }) are cascades of Add().

import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Text/CompositePatternBuilder.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/Text/LocalDateTimePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/CompositePatternBuilderPatternTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // See https://github.com/nodatime/nodatime/issues/607
    'IsoPattern': (args) {
      final [String text] = args;
      // We assert that the text round-trips. If it does, it's
      // reasonable to assume it parsed correctly...
      var shortPattern = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm");
      var pattern = (CompositePatternBuilder<LocalDateTime>()
            ..Add(LocalDateTimePattern.ExtendedIso, (_) => true)
            ..Add(shortPattern, (ldt) => ldt.Second == 0 && ldt.NanosecondOfSecond == 0))
          .Build();
      var value = pattern.Parse(text).Value;
      String formatted = pattern.Format(value);
      Assert.AreEqual(text, formatted);
    },

    'Format_NoValidPattern': (args) {
      var pattern = (CompositePatternBuilder<LocalDate>()
            ..Add(LocalDatePattern.Iso, (_) => false)
            ..Add(LocalDatePattern.CreateWithInvariantCulture('uuuu'), (_) => false))
          .Build();
      Assert.Throws<FormatException>(() => pattern.Format(LocalDate(2017, 1, 1)));
    },

    'Parse': (args) {
      var pattern = (CompositePatternBuilder<LocalDate>()
            ..Add(LocalDatePattern.Iso, (_) => true)
            ..Add(LocalDatePattern.CreateWithInvariantCulture('uuuu'), (_) => false))
          .Build();
      Assert.IsTrue(pattern.Parse('2017-03-20').Success);
      Assert.IsFalse(pattern.Parse('2017-03').Success);
      Assert.IsTrue(pattern.Parse('2017').Success);
    },

    'Build_Empty': (args) {
      var pattern = CompositePatternBuilder<LocalDate>();
      Assert.Throws<StateError>(() => pattern.Build());
    },

    'Enumerators': (args) {
      var pattern1 = LocalDatePattern.Iso;
      var pattern2 = LocalDatePattern.CreateWithInvariantCulture('uuuu');

      var builder = CompositePatternBuilder<LocalDate>()
        ..Add(pattern1, (_) => true)
        ..Add(pattern2, (_) => false);

      CollectionAssert.AreEqual([pattern1, pattern2], builder.toList());
      CollectionAssert.AreEqual([pattern1, pattern2], builder.whereType<LocalDatePattern>().toList());
    },
  });
}
