// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/PatternTestData.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the data arrays aren't ported: their values arrive as decoded scenario objects.

// ignore_for_file: avoid_dynamic_calls

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Text/IPartialPattern.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Text/UnparsableValueException.dart';
import 'package:noda_dart/src/Text/ValueCursor.dart';
import 'package:noda_dart/src/Utility/StringFormat.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/NamedWrapper.dart';

/// Alternative to AbstractFormattingData for tests which deal with patterns directly. This does not
/// include properties which are irrelevant to the pattern tests but which are used by the BCL-style
/// formatting tests (e.g. thread culture).
abstract class PatternTestData<T> {
  final T Value;

  T get DefaultTemplate;

  /// Culture of the pattern.
  NodaCultureInfo Culture = NodaCultureInfo.InvariantCulture;

  /// Standard pattern, expected to format/parse the same way as Pattern.
  IPattern<T>? StandardPattern;

  /// Pattern text.
  String? Pattern;

  /// String value to be parsed, and expected result of formatting.
  String? Text;

  /// Template value to specify in the pattern
  late T Template;

  /// Extra description for the test case
  String? Description;

  /// Message format to verify for exceptions.
  String? Message;

  /// Message parameters to verify for exceptions.
  final List<Object?> Parameters = [];

  PatternTestData(this.Value) {
    Template = DefaultTemplate;
  }

  /// noda_dart: new code. The fixture's Data from a decoded scenario object; [create] reads the fields.
  static D? FromScenario<T, D extends PatternTestData<T>>(Object? data, D Function(Map<String, Object?> fields) create) {
    if (data == null) {
      return null;
    }
    final fields = data as Map<String, Object?>;
    final result = create(fields);
    if (fields.containsKey('culture')) {
      result.Culture = fields['culture'] as NodaCultureInfo;
    }
    if (fields.containsKey('standardPattern')) {
      result.StandardPattern = fields['standardPattern'] as IPattern<T>?;
    }
    if (fields.containsKey('pattern')) {
      result.Pattern = fields['pattern'] as String?;
    }
    if (fields.containsKey('text')) {
      result.Text = fields['text'] as String?;
    }
    if (fields.containsKey('template')) {
      result.Template = fields['template'] as T;
    }
    if (fields.containsKey('description')) {
      result.Description = fields['description'] as String?;
    }
    if (fields.containsKey('message')) {
      result.Message = fields['message'] as String?;
    }
    if (fields.containsKey('parameters')) {
      result.Parameters.addAll(fields['parameters'] as List<Object?>);
    }
    return result;
  }

  IPattern<T> CreatePattern();

  void TestParse() {
    Assert.IsNull(Message);
    IPattern<T> pattern = CreatePattern();
    var result = pattern.Parse(Text!);
    var actualValue = result.Value;
    Assert.AreEqual(Value, actualValue);

    if (StandardPattern != null) {
      Assert.AreEqual(Value, StandardPattern!.Parse(Text!).Value);
    }
  }

  void TestFormat() {
    Assert.IsNull(Message);
    IPattern<T> pattern = CreatePattern();
    Assert.AreEqual(Text, pattern.Format(Value));

    if (StandardPattern != null) {
      Assert.AreEqual(Text, StandardPattern!.Format(Value));
    }
  }

  void TestParsePartial() {
    var pattern = CreatePartialPattern();
    Assert.IsNull(Message);
    var cursor = ValueCursor.NewValue('^$Text#');
    // Move to the ^
    cursor.MoveNext();
    // Move to the start of the text
    cursor.MoveNext();
    var result = pattern.ParsePartial(cursor);
    var actualValue = result.Value;
    Assert.AreEqual(Value, actualValue);
    Assert.AreEqual('#', cursor.Current);
  }

  IPartialPattern<T> CreatePartialPattern() {
    throw UnimplementedError();
  }

  void TestAppendFormat() {
    Assert.IsNull(Message);
    var pattern = CreatePattern();
    var builder = StringBuffer('x');
    pattern.AppendFormat(Value, builder);
    Assert.AreEqual('x$Text', builder.toString());
  }

  void TestInvalidPattern() {
    String expectedMessage = _FormatMessage(Message!, Parameters.toList());
    try {
      CreatePattern();
      Assert.Fail('Expected InvalidPatternException');
    } on InvalidPatternException catch (e) {
      // Expected... now let's check the message
      Assert.AreEqual(expectedMessage, e.message);
    }
  }

  void TestParseFailure() {
    String expectedMessage = _FormatMessage(Message!, Parameters.toList());
    IPattern<T> pattern = CreatePattern();
    var result = pattern.Parse(Text!);
    Assert.IsFalse(result.Success, 'Expected parsing to fail, but it succeeded');
    try {
      result.GetValueOrThrow();
      Assert.Fail('Expected UnparsableValueException');
    } on UnparsableValueException catch (e) {
      // Expected... now let's check the message *starts* with the right part.
      // We're not currently validating the bit that reproduces the bad value.
      Assert.IsTrue(e.message.startsWith(expectedMessage),
          'Expected message to start with $expectedMessage; was actually ${e.message}');

      Assert.AreEqual(Text, e.Value, 'Expected exception to include the text value');
    }
  }

  @override
  String toString() {
    try {
      StringBuffer builder = StringBuffer();
      // noda_dart: C#'s IFormattable.ToString(ValuePatternText, InvariantCulture) is ToStringPattern.
      String valueText = ValuePatternText != null
          ? (Value as dynamic).ToStringPattern(ValuePatternText, NodaCultureInfo.InvariantCulture) as String
          : Value?.toString() ?? '';
      builder.write('Value=$valueText;');
      builder.write('Pattern=$Pattern;');
      builder.write('Text=$Text;');
      if (Culture != NodaCultureInfo.InvariantCulture) {
        builder.write('Culture=$Culture;');
      }
      if (Description != null) {
        builder.write('Description=$Description;');
      }
      if (Template != DefaultTemplate) {
        builder.write('Template=$Template;');
      }
      // Trim the trailing semi-colon
      final text = builder.toString();
      return NamedWrapper.SanitizeName(text.substring(0, text.length - 1));
    } catch (e) {
      return 'Formatting of test name failed';
    }
  }

  /// Returns the pattern text to use when formatting the value for the test name.
  /// Defaults to null, implying the default pattern for the type, but can be overridden to provide
  /// a more fine-grained pattern. This property is only used if the value implements IFormattable.
  String? get ValuePatternText => null;

  /// Formats a message, giving a *useful* error message on failure. It can be a pain checking exactly what
  /// the message format is when writing tests...
  static String _FormatMessage(String message, List<Object?> parameters) {
    try {
      return StringFormat.Format(message, parameters);
    } on FormatException {
      throw FormatException("Failed to format string '$message' with ${parameters.length} parameters");
    }
  }
}
