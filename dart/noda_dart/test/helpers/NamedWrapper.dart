// Ported from NodaTime 6e024dde: src/NodaTime.Test/NamedWrapper.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

/// Test parameters are converted into strings to generate
/// test names; this can cause problems either due to non-uniqueness,
/// or due to brackets in the name. This wrapper allows custom names to
/// be provided, and automatically converts round brackets to square ones.
///
/// [T]: Type of underlying value
class NamedWrapper<T> {
  final T Value;
  final String _name;

  NamedWrapper(this.Value, String name) : _name = name;

  @override
  String toString() => SanitizeName(_name);

  static String SanitizeName(String name) => name.replaceAll('(', '[').replaceAll(')', ']');
}
