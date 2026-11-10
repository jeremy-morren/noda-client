// noda_dart: new code. Types of nodatime-api.generated.dart (as ts/test/api/types.ts).

final class ApiType {
  const ApiType({required this.name, required this.fullName, required this.kind, required this.members});

  /// noda_dart name (nested types flattened: "ZoneEqualityComparer+Options" → "ZoneEqualityComparerOptions").
  final String name;

  final String fullName;

  /// "class", "struct", "interface", "enum", "delegate" or "static class".
  final String kind;

  final List<ApiMember> members;
}

final class ApiMember {
  const ApiMember({
    required this.name,
    required this.csName,
    required this.kind,
    required this.isStatic,
    required this.signatures,
    this.bclInterop = false,
  });

  /// The C# name; "constructor", or metadata names for operators ("op_Addition").
  final String name;

  final String csName;

  /// "constructor", "property", "field", "const", "method", "operator" or "indexer".
  final String kind;

  final bool isStatic;

  final List<String> signatures;

  /// Every overload involves .NET-only types (DateTime, TimeSpan, TimeZoneInfo, XML, ...).
  final bool bclInterop;
}
