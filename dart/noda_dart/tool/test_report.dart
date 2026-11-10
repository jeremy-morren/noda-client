// noda_dart: new code. Merges CI's "<project>@<label>.json" test results into one JUnit report.
// Usage: dart run tool/test_report.dart <results directory> <junit.xml>

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run tool/test_report.dart <results directory> <junit.xml>');
    exit(64);
  }
  final files = Directory(args[0])
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && f.uri.pathSegments.last.contains('@'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final suites = <_Suite>[];
  var failures = 0;
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final at = name.indexOf('@');
    final project = name.substring(0, at);
    final label = name.substring(at + 1, name.length - '.json'.length);
    final run = _readRun(file, project, label);
    suites.addAll(run);
    for (final suite in run) {
      failures += suite.failures;
    }
    stdout.writeln('${file.path}: ${run.fold<int>(0, (n, s) => n + s.cases.length)} tests');
  }
  final xml = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<testsuites>\n');
  for (final suite in suites) {
    suite.write(xml);
  }
  xml.write('</testsuites>\n');
  File(args[1])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(xml.toString());
  stdout.writeln('${args[1]}: ${suites.length} suites, $failures failures');
}

List<_Suite> _readRun(File file, String project, String label) {
  final suitesById = <int, _Suite>{};
  final tests = <int, _Case>{};
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue; // flutter test can interleave plain output.
    }
    if (decoded is! Map<String, Object?>) continue;
    final event = decoded;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite']! as Map<String, Object?>;
        final path = ((suite['path'] as String?) ?? '?').replaceAll(r'\', '/');
        // Relative to the package, whatever the checkout's location.
        final relative = path.contains('/test/') ? 'test/${path.split('/test/').last}' : path;
        suitesById[suite['id']! as int] = _Suite('$relative [$project, $label]');
      case 'testStart':
        final test = event['test']! as Map<String, Object?>;
        final suite = suitesById[test['suiteID']! as int];
        if (suite == null) continue;
        final c = _Case(test['name']! as String, event['time']! as int);
        tests[test['id']! as int] = c;
        suite.cases.add(c);
      case 'error':
        final c = tests[event['testID']! as int];
        c?.errors.add('${event['error']}\n${event['stackTrace']}');
      case 'print':
        final c = tests[event['testID']! as int];
        c?.output.writeln(event['message']);
      case 'testDone':
        final c = tests[event['testID']! as int];
        if (c == null) continue;
        c
          ..done = true
          ..hidden = event['hidden'] == true
          ..skipped = event['skipped'] == true
          ..result = event['result']! as String
          ..endTime = event['time']! as int;
    }
  }
  for (final suite in suitesById.values) {
    // Hidden tests are package:test's internal setUpAll/tearDownAll entries, unless they failed.
    suite.cases.removeWhere((c) => c.hidden && c.result == 'success');
  }
  return suitesById.values.where((s) => s.cases.isNotEmpty).toList();
}

class _Suite {
  final String name;
  final cases = <_Case>[];
  _Suite(this.name);

  int get failures => cases.where((c) => c.failed).length;

  void write(StringBuffer xml) {
    final skipped = cases.where((c) => c.skipped).length;
    final time = cases.fold<int>(0, (t, c) => t + c.milliseconds) / 1000;
    xml.writeln('  <testsuite name="${_escape(name)}" tests="${cases.length}" failures="$failures" '
        'skipped="$skipped" time="$time">');
    for (final c in cases) {
      xml.write('    <testcase classname="${_escape(name)}" name="${_escape(c.name)}" '
          'time="${c.milliseconds / 1000}"');
      if (!c.failed && !c.skipped && c.output.isEmpty) {
        xml.writeln('/>');
        continue;
      }
      xml.writeln('>');
      if (c.skipped) xml.writeln('      <skipped/>');
      if (c.failed) {
        final message = c.errors.isEmpty ? (c.done ? c.result : 'did not complete') : c.errors.first.split('\n').first;
        xml.writeln('      <failure message="${_escape(message)}">${_escape(c.errors.join('\n\n'))}</failure>');
      }
      if (c.output.isNotEmpty) xml.writeln('      <system-out>${_escape(c.output.toString())}</system-out>');
      xml.writeln('    </testcase>');
    }
    xml.writeln('  </testsuite>');
  }
}

class _Case {
  final String name;
  final int startTime;
  int? endTime;
  bool done = false;
  bool hidden = false;
  bool skipped = false;
  String result = 'success';
  final errors = <String>[];
  final output = StringBuffer();
  _Case(this.name, this.startTime);

  bool get failed => !done || result != 'success';
  int get milliseconds => (endTime ?? startTime) - startTime;
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAllMapped(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), (m) => '&#${m[0]!.codeUnitAt(0)};');
