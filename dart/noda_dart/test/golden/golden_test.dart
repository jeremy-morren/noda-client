// noda_dart: new code. Port of noda-js's ts/test/golden/golden.test.ts: NodaTime's formatting, parsing and
// case-insensitive comparisons in every culture.

import 'package:noda_dart/cultures_all.dart';
import 'package:noda_dart/noda_dart.dart';
import 'package:test/test.dart';

import '../helpers/Assertions.dart';
import '../helpers/Decode.dart';
import 'types.dart';
import 'formatting/cs-CZ.generated.dart' as formatting_cs_cz;
import 'formatting/da-DK.generated.dart' as formatting_da_dk;
import 'formatting/de-AT.generated.dart' as formatting_de_at;
import 'formatting/de-CH.generated.dart' as formatting_de_ch;
import 'formatting/de-DE.generated.dart' as formatting_de_de;
import 'formatting/el-GR.generated.dart' as formatting_el_gr;
import 'formatting/en-001.generated.dart' as formatting_en_001;
import 'formatting/en-AU.generated.dart' as formatting_en_au;
import 'formatting/en-CA.generated.dart' as formatting_en_ca;
import 'formatting/en-GB.generated.dart' as formatting_en_gb;
import 'formatting/en-IE.generated.dart' as formatting_en_ie;
import 'formatting/en-IL.generated.dart' as formatting_en_il;
import 'formatting/en-IN.generated.dart' as formatting_en_in;
import 'formatting/en-NZ.generated.dart' as formatting_en_nz;
import 'formatting/en-US.generated.dart' as formatting_en_us;
import 'formatting/en-ZA.generated.dart' as formatting_en_za;
import 'formatting/es-419.generated.dart' as formatting_es_419;
import 'formatting/es-ES.generated.dart' as formatting_es_es;
import 'formatting/es-MX.generated.dart' as formatting_es_mx;
import 'formatting/fi-FI.generated.dart' as formatting_fi_fi;
import 'formatting/fr-CA.generated.dart' as formatting_fr_ca;
import 'formatting/fr-CH.generated.dart' as formatting_fr_ch;
import 'formatting/fr-FR.generated.dart' as formatting_fr_fr;
import 'formatting/he-IL.generated.dart' as formatting_he_il;
import 'formatting/hi-IN.generated.dart' as formatting_hi_in;
import 'formatting/id-ID.generated.dart' as formatting_id_id;
import 'formatting/invariant.generated.dart' as formatting_invariant;
import 'formatting/it-IT.generated.dart' as formatting_it_it;
import 'formatting/ja-JP.generated.dart' as formatting_ja_jp;
import 'formatting/ko-KR.generated.dart' as formatting_ko_kr;
import 'formatting/nb-NO.generated.dart' as formatting_nb_no;
import 'formatting/nl-NL.generated.dart' as formatting_nl_nl;
import 'formatting/pl-PL.generated.dart' as formatting_pl_pl;
import 'formatting/pt-BR.generated.dart' as formatting_pt_br;
import 'formatting/pt-PT.generated.dart' as formatting_pt_pt;
import 'formatting/ru-RU.generated.dart' as formatting_ru_ru;
import 'formatting/sv-SE.generated.dart' as formatting_sv_se;
import 'formatting/tr-TR.generated.dart' as formatting_tr_tr;
import 'formatting/uk-UA.generated.dart' as formatting_uk_ua;
import 'formatting/vi-VN.generated.dart' as formatting_vi_vn;
import 'formatting/zh-CN.generated.dart' as formatting_zh_cn;
import 'formatting/zh-TW.generated.dart' as formatting_zh_tw;
import 'compare/cs-CZ.generated.dart' as compare_cs_cz;
import 'compare/da-DK.generated.dart' as compare_da_dk;
import 'compare/de-AT.generated.dart' as compare_de_at;
import 'compare/de-CH.generated.dart' as compare_de_ch;
import 'compare/de-DE.generated.dart' as compare_de_de;
import 'compare/el-GR.generated.dart' as compare_el_gr;
import 'compare/en-001.generated.dart' as compare_en_001;
import 'compare/en-AU.generated.dart' as compare_en_au;
import 'compare/en-CA.generated.dart' as compare_en_ca;
import 'compare/en-GB.generated.dart' as compare_en_gb;
import 'compare/en-IE.generated.dart' as compare_en_ie;
import 'compare/en-IL.generated.dart' as compare_en_il;
import 'compare/en-IN.generated.dart' as compare_en_in;
import 'compare/en-NZ.generated.dart' as compare_en_nz;
import 'compare/en-US.generated.dart' as compare_en_us;
import 'compare/en-ZA.generated.dart' as compare_en_za;
import 'compare/es-419.generated.dart' as compare_es_419;
import 'compare/es-ES.generated.dart' as compare_es_es;
import 'compare/es-MX.generated.dart' as compare_es_mx;
import 'compare/fi-FI.generated.dart' as compare_fi_fi;
import 'compare/fr-CA.generated.dart' as compare_fr_ca;
import 'compare/fr-CH.generated.dart' as compare_fr_ch;
import 'compare/fr-FR.generated.dart' as compare_fr_fr;
import 'compare/he-IL.generated.dart' as compare_he_il;
import 'compare/hi-IN.generated.dart' as compare_hi_in;
import 'compare/id-ID.generated.dart' as compare_id_id;
import 'compare/invariant.generated.dart' as compare_invariant;
import 'compare/it-IT.generated.dart' as compare_it_it;
import 'compare/ja-JP.generated.dart' as compare_ja_jp;
import 'compare/ko-KR.generated.dart' as compare_ko_kr;
import 'compare/nb-NO.generated.dart' as compare_nb_no;
import 'compare/nl-NL.generated.dart' as compare_nl_nl;
import 'compare/pl-PL.generated.dart' as compare_pl_pl;
import 'compare/pt-BR.generated.dart' as compare_pt_br;
import 'compare/pt-PT.generated.dart' as compare_pt_pt;
import 'compare/ru-RU.generated.dart' as compare_ru_ru;
import 'compare/sv-SE.generated.dart' as compare_sv_se;
import 'compare/tr-TR.generated.dart' as compare_tr_tr;
import 'compare/uk-UA.generated.dart' as compare_uk_ua;
import 'compare/vi-VN.generated.dart' as compare_vi_vn;
import 'compare/zh-CN.generated.dart' as compare_zh_cn;
import 'compare/zh-TW.generated.dart' as compare_zh_tw;

const List<FormattingGolden> formattingGoldens = [
  formatting_cs_cz.golden,
  formatting_da_dk.golden,
  formatting_de_at.golden,
  formatting_de_ch.golden,
  formatting_de_de.golden,
  formatting_el_gr.golden,
  formatting_en_001.golden,
  formatting_en_au.golden,
  formatting_en_ca.golden,
  formatting_en_gb.golden,
  formatting_en_ie.golden,
  formatting_en_il.golden,
  formatting_en_in.golden,
  formatting_en_nz.golden,
  formatting_en_us.golden,
  formatting_en_za.golden,
  formatting_es_419.golden,
  formatting_es_es.golden,
  formatting_es_mx.golden,
  formatting_fi_fi.golden,
  formatting_fr_ca.golden,
  formatting_fr_ch.golden,
  formatting_fr_fr.golden,
  formatting_he_il.golden,
  formatting_hi_in.golden,
  formatting_id_id.golden,
  formatting_invariant.golden,
  formatting_it_it.golden,
  formatting_ja_jp.golden,
  formatting_ko_kr.golden,
  formatting_nb_no.golden,
  formatting_nl_nl.golden,
  formatting_pl_pl.golden,
  formatting_pt_br.golden,
  formatting_pt_pt.golden,
  formatting_ru_ru.golden,
  formatting_sv_se.golden,
  formatting_tr_tr.golden,
  formatting_uk_ua.golden,
  formatting_vi_vn.golden,
  formatting_zh_cn.golden,
  formatting_zh_tw.golden,
];

const List<CompareGolden> compareGoldens = [
  compare_cs_cz.golden,
  compare_da_dk.golden,
  compare_de_at.golden,
  compare_de_ch.golden,
  compare_de_de.golden,
  compare_el_gr.golden,
  compare_en_001.golden,
  compare_en_au.golden,
  compare_en_ca.golden,
  compare_en_gb.golden,
  compare_en_ie.golden,
  compare_en_il.golden,
  compare_en_in.golden,
  compare_en_nz.golden,
  compare_en_us.golden,
  compare_en_za.golden,
  compare_es_419.golden,
  compare_es_es.golden,
  compare_es_mx.golden,
  compare_fi_fi.golden,
  compare_fr_ca.golden,
  compare_fr_ch.golden,
  compare_fr_fr.golden,
  compare_he_il.golden,
  compare_hi_in.golden,
  compare_id_id.golden,
  compare_invariant.golden,
  compare_it_it.golden,
  compare_ja_jp.golden,
  compare_ko_kr.golden,
  compare_nb_no.golden,
  compare_nl_nl.golden,
  compare_pl_pl.golden,
  compare_pt_br.golden,
  compare_pt_pt.golden,
  compare_ru_ru.golden,
  compare_sv_se.golden,
  compare_tr_tr.golden,
  compare_uk_ua.golden,
  compare_vi_vn.golden,
  compare_zh_cn.golden,
  compare_zh_tw.golden,
];

// Every culture, through the package:noda_dart/cultures_all.dart entry point, by name.
final Map<String, NodaCultureInfo> culturesByName = {for (final c in AllCultures) c.Name: c};

NodaCultureInfo culture(String name) {
  if (name == '') {
    return NodaCultureInfo.InvariantCulture;
  }
  final found = culturesByName[name];
  if (found == null) {
    throw StateError('No culture $name exported from package:noda_dart/cultures_all.dart');
  }
  return found;
}

IPattern<Object> createPattern(String type, String patternText, NodaCultureInfo cultureInfo) => switch (type) {
      'AnnualDate' => AnnualDatePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'Duration' => DurationPattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'Instant' => InstantPattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'LocalDate' => LocalDatePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'LocalDateTime' => LocalDateTimePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'LocalTime' => LocalTimePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'Offset' => OffsetPattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'OffsetDate' => OffsetDatePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'OffsetDateTime' => OffsetDateTimePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'OffsetTime' => OffsetTimePattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'Period' => throw StateError('PeriodPattern has no culture-specific patterns'),
      'YearMonth' => YearMonthPattern.CreateWithInvariantCulture(patternText).WithCulture(cultureInfo),
      'ZonedDateTime' =>
        ZonedDateTimePattern.CreateWithInvariantCulture(patternText, tzdbProvider).WithCulture(cultureInfo),
      _ => throw StateError('No pattern type for $type'),
    };

// One test per culture and type, not per vector: 52,000 tests time out loading in browsers.
void main() {
  for (final golden in formattingGoldens) {
    final cultureName = golden.culture == '' ? 'invariant' : golden.culture;
    final byType = <String, List<FormattingCase>>{};
    for (final testCase in golden.cases) {
      byType.putIfAbsent(testCase.type, () => []).add(testCase);
    }
    group('formatting [$cultureName]', () {
      for (final MapEntry(key: type, value: cases) in byType.entries) {
        test('$type (${cases.length} vectors)', () {
          final failures = <String>[];
          var unsupported = 0;
          for (final testCase in cases) {
            final label = '$type "${testCase.pattern}" ${testCase.text ?? testCase.error}';
            final Object value;
            try {
              value = decode(testCase.value)!;
            } on UnsupportedValue {
              unsupported++;
              continue;
            }
            try {
              final pattern = createPattern(testCase.type, testCase.pattern, culture(golden.culture));
              final text = testCase.text;
              if (text == null) {
                expect(() => pattern.Format(value), throwsA(anything));
                continue;
              }
              expect(pattern.Format(value), text);
              if (testCase.roundTrips == true) {
                final result = pattern.Parse(text);
                expect(result.Success, isTrue, reason: result.Success ? '' : '${result.Exception}');
                Assert.AreEqual(value, result.Value);
              }
            } catch (e) {
              failures.add('$label: $e');
            }
          }
          if (unsupported == cases.length) {
            markTestSkipped('every vector has a value noda_dart cannot decode');
          }
          expect(failures, isEmpty, reason: '${failures.length} of ${cases.length} vectors failed');
        });
      }
    });
  }

  for (final golden in compareGoldens) {
    final cultureName = golden.culture == '' ? 'invariant' : golden.culture;
    test('CompareInfo [$cultureName] (${golden.cases.length} pairs)', () {
      final compareInfo = culture(golden.culture).CompareInfo;
      final failures = [
        for (final (text, candidate, equal) in golden.cases)
          if ((compareInfo.Compare(text, candidate, CompareOptions.IgnoreCase) == 0) != equal)
            '$text vs $candidate: expected ${equal ? 'equal' : 'different'}',
      ];
      expect(failures, isEmpty, reason: '${failures.length} of ${golden.cases.length} pairs failed');
    });
  }
}
