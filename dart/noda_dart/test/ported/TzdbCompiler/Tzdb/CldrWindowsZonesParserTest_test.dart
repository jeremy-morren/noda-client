// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/CldrWindowsZonesParserTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: not ported: the CLDR mapping is generated data (lib/src/Bcl/CldrWindowsZones.dart).

import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/CldrWindowsZonesParserTest.generated.dart' as scenarios;

const String _NotPorted = "CldrWindowsZonesParser (CLDR windowsZones.xml parsing, with System.Xml.Linq) isn't ported: "
    'noda_dart has the CLDR Windows mapping as generated data';

void main() {
  port(scenarios.fixture, {}, skip: {
    'Versions_Present': _NotPorted,
    'Versions_Absent': _NotPorted,
    'MapZones': _NotPorted,
  });
}
