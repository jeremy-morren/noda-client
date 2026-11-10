// Ported from NodaTime 6e024dde: src/NodaTime/Utility/ReferenceEqualityComparer.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Comparers.dart';

/// An equality comparer which compares references for equality and uses the "original" object hash code
/// for hash codes. This is broadly equivalent to System.Collections.Generic.ReferenceEqualityComparer, but that's
/// only available from .NET 5.
@internal
final class ReferenceEqualityComparer<T extends Object> implements IEqualityComparer<T> {
  const ReferenceEqualityComparer();

  @override
  bool Equals(T? first, T? second) => identical(first, second);

  @override
  int GetHashCode(T? value) => value == null ? 0 : identityHashCode(value);
}
