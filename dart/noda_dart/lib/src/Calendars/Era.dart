// Ported from NodaTime 6e024dde: src/NodaTime/Calendars/Era.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

/// Represents an era used in a calendar.
///
/// All the built-in calendars in Noda Time use the values specified by the static
/// read-only fields in this class. These may be compared for reference equality to check for specific
/// eras.
///
/// This type is immutable reference type. See the thread safety section of the user guide for more information.
final class Era {
  /// The "Common" era (CE), also known as Anno Domini (AD). This is used in the ISO, Gregorian and Julian calendars.
  static final Era Common = Era.NewNameResourceIdentifier('CE', 'Eras_Common');

  /// The "before common" era (BCE), also known as Before Christ (BC). This is used in the ISO, Gregorian and Julian calendars.
  static final Era BeforeCommon = Era.NewNameResourceIdentifier('BCE', 'Eras_BeforeCommon');

  /// The "Anno Martyrum" or "Era of the Martyrs". This is the sole era used in the Coptic calendar.
  static final Era AnnoMartyrum = Era.NewNameResourceIdentifier('AM', 'Eras_AnnoMartyrum');

  /// The "Anno Hegira" era. This is the sole era used in the Hijri (Islamic) calendar.
  static final Era AnnoHegirae = Era.NewNameResourceIdentifier('EH', 'Eras_AnnoHegirae');

  /// The "Anno Mundi" era. This is the sole era used in the Hebrew calendar.
  static final Era AnnoMundi = Era.NewNameResourceIdentifier('AM', 'Eras_AnnoMundi');

  /// The "Anno Persico" era. This is the sole era used in the Persian calendar.
  static final Era AnnoPersico = Era.NewNameResourceIdentifier('AP', 'Eras_AnnoPersico');

  /// The "Bahá'í" era. This is the sole era used in the Badi calendar.
  static final Era Bahai = Era.NewNameResourceIdentifier('BE', 'Eras_Bahai');

  @internal
  final String ResourceIdentifier;

  /// Returns the name of this era, e.g. "CE" or "BCE".
  final String Name;

  @internal
  Era.NewNameResourceIdentifier(String name, String resourceIdentifier)
      : Name = name,
        ResourceIdentifier = resourceIdentifier;

  /// Returns the name of this era.
  @override
  String toString() => Name;
}
