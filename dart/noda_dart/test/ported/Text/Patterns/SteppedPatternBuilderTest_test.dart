// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/Patterns/SteppedPatternBuilderTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s chars are one-character strings.

import 'package:noda_dart/src/Globalization/NodaFormatInfo.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Text/Delegates.dart';
import 'package:noda_dart/src/Text/IPartialPattern.dart';
import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Text/OffsetPatternParser.dart';
import 'package:noda_dart/src/Text/ParseBucket.dart';
import 'package:noda_dart/src/Text/ParseResult.dart';
import 'package:noda_dart/src/Text/Patterns/PatternCursor.dart';
import 'package:noda_dart/src/Text/Patterns/PatternFields.dart';
import 'package:noda_dart/src/Text/Patterns/SteppedPatternBuilder.dart';
import 'package:noda_dart/src/Text/TextCursor.dart';
import 'package:noda_dart/src/Text/TextErrorMessages.generated.dart';
import 'package:noda_dart/src/Text/UnparsableValueException.dart';
import 'package:noda_dart/src/Text/ValueCursor.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/Text/Patterns/SteppedPatternBuilderTest.generated.dart' as scenarios;

/// Tests for SteppedPatternBuilder, often using OffsetPatternParser as this is known
/// to use SteppedPatternBuilder.
final IPartialPattern<Offset> SimpleOffsetPattern =
    OffsetPatternParser().ParsePattern('HH:mm', NodaFormatInfo.InvariantInfo) as IPartialPattern<Offset>;

void main() {
  port(scenarios.fixture, {
    'ParsePartial_ValidInMiddle': (args) {
      var value = ValueCursor.NewValue('x17:30y');
      value.MoveNext();
      value.MoveNext();
      // Start already looking at the value to parse
      Assert.AreEqual('1', value.Current);
      var result = SimpleOffsetPattern.ParsePartial(value);
      Assert.AreEqual(Offset.FromHoursAndMinutes(17, 30), result.Value);
      // Finish just after the value
      Assert.AreEqual('y', value.Current);
    },

    'ParsePartial_ValidAtEnd': (args) {
      var value = ValueCursor.NewValue('x17:30');
      value.MoveNext();
      value.MoveNext();
      var result = SimpleOffsetPattern.ParsePartial(value);
      Assert.AreEqual(Offset.FromHoursAndMinutes(17, 30), result.Value);
      // Finish just after the value, which in this case is at the end.
      Assert.AreEqual(TextCursor.Nul, value.Current);
    },

    'ParsePartial_Invalid': (args) {
      var value = ValueCursor.NewValue('x17:y');
      value.MoveNext();
      value.MoveNext();
      var result = SimpleOffsetPattern.ParsePartial(value);
      var exception = Assert.Throws<UnparsableValueException>(() => result.GetValueOrThrow());
      Assert.AreEqual('x17:y', exception.Value);
      Assert.AreEqual(4, exception.Index);
    },

    'FormatOnly_ParsingFails': (args) {
      var builder = SteppedPatternBuilder<LocalDate, SampleBucket>.NewFormatInfoBucketProvider(
          NodaFormatInfo.InvariantInfo, () => SampleBucket());
      builder.AddFormatAction((date, sb) => sb.write('Formatted'));
      builder.SetFormatOnly();
      var pattern = builder.Build(LocalDate.MinIsoValue);

      var value = ValueCursor.NewValue('xyz');
      var result = pattern.ParsePartial(value);
      Assert.IsFalse(result.Success);
      Assert.IsInstanceOf<UnparsableValueException>(result.Exception);
      Assert.AreEqual('xyz', (result.Exception as UnparsableValueException).Value);
      Assert.AreEqual(-1, (result.Exception as UnparsableValueException).Index);
      Assert.AreEqual(TextErrorMessages.FormatOnlyPattern, (result.Exception as UnparsableValueException).message);
      result = pattern.Parse('xyz');
      Assert.IsFalse(result.Success);
      Assert.IsInstanceOf<UnparsableValueException>(result.Exception);
      Assert.AreEqual('xyz', (result.Exception as UnparsableValueException).Value);
      Assert.AreEqual(-1, (result.Exception as UnparsableValueException).Index);
      Assert.AreEqual(TextErrorMessages.FormatOnlyPattern, (result.Exception as UnparsableValueException).message);
    },

    'AppendFormat': (args) {
      var builder = StringBuffer('x');
      var offset = Offset.FromHoursAndMinutes(17, 30);
      SimpleOffsetPattern.AppendFormat(offset, builder);
      Assert.AreEqual('x17:30', builder.toString());
    },

    'UnhandledLiteral': (args) {
      final [String text, bool valid] = args;
      void handler(PatternCursor patternCursor, SteppedPatternBuilder<LocalDate, SampleBucket> patternBuilder) {}
      var handlers = <String, CharacterHandler<LocalDate, SampleBucket>>{
        'a': handler,
        'B': handler,
      };
      var builder = SteppedPatternBuilder<LocalDate, SampleBucket>.NewFormatInfoBucketProvider(
          NodaFormatInfo.InvariantInfo, () => SampleBucket());
      if (valid) {
        builder.ParseCustomPattern(text, handlers);
      } else {
        Assert.Throws<InvalidPatternException>(() => builder.ParseCustomPattern(text, handlers));
      }
    },
  });
}

final class SampleBucket extends ParseBucket<LocalDate> {
  @override
  ParseResult<LocalDate> CalculateValue(PatternFields usedFields, String value) {
    throw UnimplementedError();
  }
}
