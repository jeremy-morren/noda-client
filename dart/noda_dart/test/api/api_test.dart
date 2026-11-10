// noda_dart: new code. Port of noda-js's ts/test/api/api.test.ts: our public API against NodaTime's, by name and kind
// (not signature), read with package:analyzer (VM only). Deliberate differences: differences.dart.

@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:test/test.dart';

import 'differences.dart';
import 'nodatime-api.generated.dart';
import 'types.dart';

final List<String> publicLibraries = Directory('lib')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => 'package:noda_dart/${f.uri.pathSegments.last}')
    .toList()
  ..sort();

/// Null if Dart has no such operator.
const Map<String, String?> operatorNames = {
  'op_Addition': '+',
  'op_Subtraction': '-',
  'op_Multiply': '*',
  'op_Division': '/',
  'op_UnaryNegation': 'unary-',
  'op_Equality': '==',
  'op_Inequality': '==',
  'op_LessThan': '<',
  'op_LessThanOrEqual': '<=',
  'op_GreaterThan': '>',
  'op_GreaterThanOrEqual': '>=',
  'op_UnaryPlus': null,
  'op_Implicit': null,
  'op_Explicit': null,
};

const Map<String, String> dartProtocolNames = {
  'ToString': 'toString',
  'GetHashCode': 'hashCode',
  'GetEnumerator': 'iterator',
};

late final Map<String, (Element, String)> exported;
late LibraryElement anyLibrary;

Future<void> loadPublicApi() async {
  final collection = AnalysisContextCollection(includedPaths: [Directory('lib').absolute.path]);
  final session = collection.contexts.single.currentSession;
  final result = <String, (Element, String)>{};
  for (final uri in publicLibraries) {
    final library = await session.getLibraryByUri(uri);
    if (library is! LibraryElementResult) {
      throw StateError('Could not analyze $uri: $library');
    }
    anyLibrary = library.element;
    for (final MapEntry(key: name, value: element) in library.element.exportNamespace.definedNames2.entries) {
      result.putIfAbsent(name, () => (element, uri));
    }
  }
  exported = result;
}

String? checkMember(ApiType type, Element dartType, ApiMember member) {
  final key = '${type.name}.${member.csName}';
  final library = anyLibrary;
  if (dartType is TypeAliasElement) {
    return null; // A delegate: a typedef, no members.
  }
  if (dartType is! InstanceElement) {
    return '${type.name} is a ${dartType.kind.displayName}, not a type with members';
  }
  final isExtension = dartType is ExtensionElement;
  // C# extension methods are static methods of a static class; Dart's are instance members of an extension.
  final isStatic = member.isStatic && !(isExtension && member.kind == 'method');

  GetterElement? getter(String name) => isStatic || dartType is! InterfaceElement
      ? dartType.getGetter(name)
      : dartType.lookUpGetter(name: name, library: library);
  MethodElement? method(String name) => isStatic || dartType is! InterfaceElement
      ? dartType.getMethod(name)
      : dartType.lookUpMethod(name: name, library: library);
  String staticness(ExecutableElement e) =>
      e.isStatic == isStatic ? '' : '$key is ${isStatic ? '' : 'not '}static in C#, but ${e.name} is${e.isStatic ? '' : ' not'} static';

  var name = renamed[key] ?? dartProtocolNames[member.csName] ?? member.name;
  switch (member.kind) {
    case 'constructor':
      if (dartType is! InterfaceElement) {
        return '${type.name} has public C# constructors, but isn\'t a class';
      }
      final constructors = dartType.constructors.where((c) => c.isPublic);
      return constructors.isEmpty ? '${type.name} has public C# constructors, but no public Dart constructor' : null;
    case 'operator':
      final operator = operatorNames[member.csName];
      if (operator == null) {
        return null; // No Dart equivalent (conversions, unary +): see the header.
      }
      final found = method(renamed[key] ?? operator);
      return found == null ? '$key → operator $operator is missing' : null;
    case 'indexer':
      return method('[]') == null ? '$key → operator [] is missing' : null;
    case 'property':
    case 'field':
    case 'const':
      final found = getter(name);
      if (found == null) {
        final asMethod = method(name);
        return asMethod != null
            ? '$key is a C# ${member.kind}, so $name must be a getter (or field), not a method'
            : '$key → ${isStatic ? 'static ' : ''}$name is missing';
      }
      return staticness(found).isEmpty ? null : staticness(found);
    case 'method':
      if (member.csName == 'Equals' && member.signatures.every((s) => s.startsWith('(object '))) {
        name = '=='; // Equals(object) is Dart's ==.
      }
      if (member.csName == 'GetHashCode' || member.csName == 'GetEnumerator') {
        return getter(name) == null ? '$key → $name is missing' : null;
      }
      final found = method(name);
      if (found == null) {
        return getter(name) != null
            ? '$key is a C# method, so $name must be a method, not a getter'
            : '$key → ${isStatic ? 'static ' : ''}$name is missing';
      }
      return staticness(found).isEmpty ? null : staticness(found);
  }
  return 'Unknown member kind ${member.kind}';
}

void main() {
  setUpAll(loadPublicApi);

  test('every difference refers to NodaTime\'s API', () {
    final keys = {
      for (final type in NodaTimeApi) ...[type.name, for (final member in type.members) '${type.name}.${member.csName}'],
    };
    final stale = [...notPorted.keys, ...renamed.keys, ...renamedTypes.keys].where((k) => !keys.contains(k)).toList();
    expect(stale, isEmpty, reason: 'differences.dart entries for members NodaTime doesn\'t have');
  });

  for (final type in NodaTimeApi) {
    group(type.fullName, () {
      final typeReason = notPorted[type.name];
      if (typeReason != null) {
        test('not ported: $typeReason', () {}, skip: typeReason);
        return;
      }
      final dartName = renamedTypes[type.name] ?? type.name;
      test('exists', () {
        expect(exported[dartName], isNotNull, reason: '$dartName is not exported from ${publicLibraries.join(', ')}');
      });
      for (final member in type.members) {
        final key = '${type.name}.${member.csName}';
        final label = '${member.kind} ${member.isStatic ? 'static ' : ''}${member.csName}';
        final reason = notPorted[key];
        if (reason != null) {
          test(label, () {}, skip: 'not ported: $reason');
          continue;
        }
        test(label, () {
          final dartType = exported[dartName];
          expect(dartType, isNotNull, reason: '$dartName is not exported');
          final failure = checkMember(type, dartType!.$1, member);
          if (failure != null) {
            fail(failure);
          }
        });
      }
    });
  }
}
