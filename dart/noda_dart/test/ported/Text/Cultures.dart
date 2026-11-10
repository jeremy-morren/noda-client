// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/Cultures.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: each culture is the scenario culture 'Cultures.<Name>'; fixtures using them pass `cultures: scenarioCultures`.

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';

import '../../helpers/Decode.dart';

/// Cultures to use from various tests.
abstract final class Cultures {
  // Not ported: AllCultures (CultureInfo.GetCultures; the scenarios list the cultures they use, by name).

  static NodaCultureInfo get Invariant => NodaCultureInfo.InvariantCulture;

  // Specify en-US patterns explicitly, as .NET Core on Linux gives a different answer. We
  // don't need it to be US English really, just an example...
  static NodaCultureInfo get EnUs => scenarioCulture('Cultures.EnUs');

  // Specify fr-FR patterns explicitly, as .NET Core on Linux has different information.
  // We don't need it to be French really, just an example...
  static NodaCultureInfo get FrFr => scenarioCulture('Cultures.FrFr');

  static NodaCultureInfo get FrCa => scenarioCulture('Cultures.FrCa');

  static NodaCultureInfo get DotTimeSeparator => scenarioCulture('Cultures.DotTimeSeparator');

  static NodaCultureInfo get GenitiveNameTestCulture => scenarioCulture('Cultures.GenitiveNameTestCulture');

  static NodaCultureInfo get GenitiveNameTestCultureWithLeadingNames =>
      scenarioCulture('Cultures.GenitiveNameTestCultureWithLeadingNames');

  static NodaCultureInfo get AwkwardDayOfWeekCulture => scenarioCulture('Cultures.AwkwardDayOfWeekCulture');

  static NodaCultureInfo get AwkwardAmPmDesignatorCulture => scenarioCulture('Cultures.AwkwardAmPmDesignatorCulture');

  // Not ported: the culture builders (the generator applies them to .NET's cultures).
}
