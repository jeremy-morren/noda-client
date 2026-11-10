// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/PatternFields.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

// noda_dart: also exports the generated PatternFields enum.

import 'package:meta/meta.dart';

import 'PatternFields.generated.dart';

export 'PatternFields.generated.dart';

@internal
extension PatternFieldsExtensions on PatternFields {
  bool HasAny(PatternFields target) => (value & target.value) != 0;

  bool HasAll(PatternFields target) => (value & target.value) == target.value;
}
