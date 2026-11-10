// Ported from NodaTime 6e024dde: src/NodaTime.Test/Xml/XmlSchemaTest.cs
// Copyright 2020 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator (XML serialization isn't ported).

import '../../helpers/Scenarios.dart';
import '../../scenarios/Xml/XmlSchemaTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {}, skip: {
    'XmlSchema': SkipReasons.Xml,
    'XmlSchemaExporter': SkipReasons.Xml,
    'ValidXmlDocumentWithAllTypes': SkipReasons.Xml,
    'UnknownFutureZoneIdIsValid': SkipReasons.Xml,
    'AnnualDateMinValue': SkipReasons.Xml,
    'AnnualDateMaxValue': SkipReasons.Xml,
    'DurationMinValue': SkipReasons.Xml,
    'InstantMinValue': SkipReasons.Xml,
    'InstantMaxValue': SkipReasons.Xml,
    'IntervalMinValue': SkipReasons.Xml,
    'IntervalMaxValue': SkipReasons.Xml,
    'IntervalWithoutStart': SkipReasons.Xml,
    'IntervalWithoutEnd': SkipReasons.Xml,
    'IntervalWithoutStartNorEnd': SkipReasons.Xml,
    'LocalDateMinValue': SkipReasons.Xml,
    'LocalDateMaxValue': SkipReasons.Xml,
    'LocalDateTimeMinValue': SkipReasons.Xml,
    'LocalDateTimeMaxValue': SkipReasons.Xml,
    'LocalTimeMinValue': SkipReasons.Xml,
    'LocalTimeMaxValue': SkipReasons.Xml,
    'OffsetMinValue': SkipReasons.Xml,
    'OffsetMaxValue': SkipReasons.Xml,
    'OffsetDateMinValue': SkipReasons.Xml,
    'OffsetDateMaxValue': SkipReasons.Xml,
    'OffsetDateTimeMinValue': SkipReasons.Xml,
    'OffsetDateTimeMaxValue': SkipReasons.Xml,
    'OffsetTimeMinValue': SkipReasons.Xml,
    'OffsetTimeMaxValue': SkipReasons.Xml,
    'PeriodMinValue': SkipReasons.Xml,
    'PeriodMaxValue': SkipReasons.Xml,
    'YearMonthMinValue': SkipReasons.Xml,
    'YearMonthMaxValue': SkipReasons.Xml,
    'ZonedDateTimeMinValue': SkipReasons.Xml,
    'ZonedDateTimeMaxValue': SkipReasons.Xml,
  });
}
