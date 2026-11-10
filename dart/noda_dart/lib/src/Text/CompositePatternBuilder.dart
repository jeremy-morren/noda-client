// Ported from NodaTime 6e024dde: src/NodaTime/Text/CompositePatternBuilder.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Utility/Preconditions.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'ParseResult.dart';
import 'ValueCursor.dart';

/// A builder for composite patterns.
///
/// A composite pattern is a combination of multiple patterns. When parsing, these are checked
/// in the order in which they are added to the builder with the [Add]
/// method, by trying to parse and seeing if the result is a successful one. When formatting,
/// the patterns are checked in the reverse order, using the predicate provided along with the pattern
/// when calling `Add`. The intention is that patterns are added in "most precise first" order,
/// and the predicate should indicate whether it can fully represent the given value - so the "less precise"
/// (and therefore usually shorter) pattern can be used first.
///
/// [T]: The type of value to be parsed or formatted by the resulting pattern.
final class CompositePatternBuilder<T> extends Iterable<IPattern<T>> {
  final List<IPattern<T>> _patterns = <IPattern<T>>[];
  final List<bool Function(T)> _formatPredicates = <bool Function(T)>[];

  /// Constructs a new instance which initially has no component patterns. At least one component
  /// pattern must be added before [Build] is called.
  CompositePatternBuilder();

  /// Adds a component pattern to this builder.
  ///
  /// [pattern]: The component pattern to use as part of the eventual composite pattern.
  /// [formatPredicate]: A predicate to determine whether or not this pattern is suitable for
  /// formatting the given value.
  void Add(IPattern<T> pattern, bool Function(T) formatPredicate) {
    // Dart: null safety checks pattern and formatPredicate.
    _patterns.add(pattern);
    _formatPredicates.add(formatPredicate);
  }

  /// Builds a composite pattern from this builder. Further changes to this builder
  /// will have no impact on the returned pattern.
  ///
  /// Throws [StateError]: No component patterns have been added.
  ///
  /// Returns a pattern using the patterns added to this builder.
  IPattern<T> Build() {
    Preconditions.CheckState(_patterns.isNotEmpty, 'A composite pattern must have at least one component pattern.');
    return _CompositePattern<T>(_patterns, _formatPredicates);
  }

  @internal
  IPartialPattern<T> BuildAsPartial() {
    Preconditions.DebugCheckState(_patterns.every((p) => p is IPartialPattern<T>), 'All patterns should be partial');
    return Build() as IPartialPattern<T>;
  }

  @override
  Iterator<IPattern<T>> get iterator => _patterns.iterator;
}

final class _CompositePattern<T> implements IPartialPattern<T> {
  final List<IPattern<T>> _patterns;
  final List<bool Function(T)> _formatPredicates;

  _CompositePattern(List<IPattern<T>> patterns, List<bool Function(T)> formatPredicates)
      : _patterns = List<IPattern<T>>.of(patterns, growable: false),
        _formatPredicates = List<bool Function(T)>.of(formatPredicates, growable: false);

  @override
  ParseResult<T> Parse(String text) {
    for (IPattern<T> pattern in _patterns) {
      ParseResult<T> result = pattern.Parse(text);
      if (result.Success || !result.ContinueAfterErrorWithMultipleFormats) {
        return result;
      }
    }
    return ParseResult.NoMatchingFormat<T>(ValueCursor.NewValue(text));
  }

  @override
  ParseResult<T> ParsePartial(ValueCursor cursor) {
    int index = cursor.Index;
    for (IPattern<T> pattern in _patterns) {
      cursor.Move(index);
      ParseResult<T> result = (pattern as IPartialPattern<T>).ParsePartial(cursor);
      if (result.Success || !result.ContinueAfterErrorWithMultipleFormats) {
        return result;
      }
    }
    cursor.Move(index);
    return ParseResult.NoMatchingFormat<T>(cursor);
  }

  @override
  String Format(T value) => _FindFormatPattern(value).Format(value);

  @override
  StringBuffer AppendFormat(T value, StringBuffer builder) => _FindFormatPattern(value).AppendFormat(value, builder);

  IPattern<T> _FindFormatPattern(T value) {
    for (int i = _formatPredicates.length - 1; i >= 0; i--) {
      if (_formatPredicates[i](value)) {
        return _patterns[i];
      }
    }
    throw const FormatException('Composite pattern was unable to format value using any of the provided patterns.');
  }
}
