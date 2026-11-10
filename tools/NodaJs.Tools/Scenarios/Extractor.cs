using System.Globalization;
using System.Reflection;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using NodaJs.Tools.Common;
using NUnit.Framework.Api;
using NUnit.Framework.Interfaces;
using NUnit.Framework.Internal;

namespace NodaJs.Tools.Scenarios
{
    /// <summary>
    /// <c>scenarios</c>: every NUnit test in NodaTime.Test and NodaTime.TzdbCompiler.Test, with its cases as NUnit itself
    /// enumerates them.
    /// </summary>
    internal sealed class Extractor(GeneratedFiles output)
    {
        private const string Command = "scenarios";
        private static readonly Assembly TestAssembly = typeof(NodaTime.Test.Text.PatternTestBase<>).Assembly;
        private static readonly Assembly CompilerTestAssembly = typeof(NodaTime.TzdbCompiler.Test.ProgramTest).Assembly;
        private static readonly Assembly NodaTimeAssembly = typeof(NodaTime.Instant).Assembly;
        private static readonly Assembly TestingAssembly = typeof(NodaTime.Testing.FakeClock).Assembly;
        private static readonly Assembly CompilerAssembly = typeof(NodaTime.TzdbCompiler.Tzdb.TzdbDatabase).Assembly;

        private sealed record TestProject(Assembly Assembly, string Namespace, string Folder);

        private static readonly TestProject[] TestProjects =
        [
            new(TestAssembly, "NodaTime.Test", ""),
            new(CompilerTestAssembly, "NodaTime.TzdbCompiler.Test", "TzdbCompiler/"),
        ];

        // The compiler's assemblies come last, so the names of NodaTime's own instances don't change.
        private readonly StaticReferences _statics = new([NodaTimeAssembly, TestingAssembly, TestAssembly, CompilerAssembly, CompilerTestAssembly]);
        private readonly SortedDictionary<string, CultureInfo> _cultures = new(StringComparer.Ordinal);
        private readonly SourceLocations _locations = new(TestProjects.Select(p => p.Assembly));
        private readonly List<ExclusionRule> _exclusions = LoadExclusions();
        private ValueEncoder _encoder = null!;

        private sealed record FixtureModel(string Name, string Path, string Source, string? Excluded, IReadOnlyList<TestModel> Tests)
        {
            public int CaseCount => Tests.Sum(t => t.Cases?.Count ?? 0);
        }

        /// <summary><see cref="Cases"/> is null when <see cref="Excluded"/> isn't "".</summary>
        private sealed record TestModel(
            string Method,
            string Source,
            IReadOnlyList<string> Parameters,
            string? DeclaredIn,
            string Excluded,
            RunStateModel? RunState,
            IReadOnlyList<CaseModel>? Cases);

        private sealed record CaseModel(
            IReadOnlyList<EncodedValue> Args,
            string? EncodingError,
            bool HasExpected,
            EncodedValue? Expected,
            string? Description,
            RunStateModel? RunState)
        {
            private IEnumerable<EncodedValue> Values => Expected is null ? Args : Args.Append(Expected);

            public bool ExceedsDoublePrecision => Values.Any(v => v.ExceedsDoublePrecision);

            public bool IsDartConstant => Values.All(v => v.IsDartConstant);
        }

        /// <summary>A non-runnable state: <c>ignored: "reason"</c>, <c>explicit: true</c>, ...</summary>
        private sealed record RunStateModel(RunState State, string? Reason)
        {
            /// <summary>The value of <paramref name="state"/>'s property; null (left out) for the other states.</summary>
            public string? Value(CodeWriter writer, RunState state) =>
                State != state ? null : Reason is null ? writer.Bool(true) : writer.Str(Reason);
        }

        /// <summary>A rule of tools/scenario-exclusions.txt: a test name, or a prefix ending in '*'.</summary>
        private sealed record ExclusionRule(string Rule, string Reason);

        private sealed record FoundFixture(TestSuite Fixture, TestProject Project);

        /// <summary>A fixture in the index: its NUnit full name and generated file's path.</summary>
        private sealed record IndexEntry(string Name, string Path);

        public void Run()
        {
            _encoder = new ValueEncoder { Override = Override };
            _encoder.StructuralAssemblies.UnionWith([TestAssembly, CompilerTestAssembly, CompilerAssembly]);

            var fixtures = TestProjects
                .SelectMany(project =>
                {
                    var root = new DefaultTestAssemblyBuilder().Build(project.Assembly, new Dictionary<string, object>());
                    var found = new List<TestSuite>();
                    CollectFixtures(root, found);
                    return found.Select(f => new FoundFixture(f, project));
                })
                .OrderBy(f => f.Fixture.FullName, StringComparer.Ordinal)
                .ToList();

            int caseCount = 0, testCount = 0;
            var index = fixtures
                .Select(f =>
                {
                    var model = ExtractFixture(f.Fixture, f.Project);
                    foreach (var port in LangTarget.All)
                        output.Write(port.Test("scenarios/" + model.Path), Command, WriteFixture(port.NewWriter(), model));
                    testCount += model.Tests.Count;
                    caseCount += model.CaseCount;
                    return new IndexEntry(model.Name, model.Path);
                })
                .ToList();

            string[] indexHeader = [$"{index.Count} fixtures, {testCount} test methods, {caseCount} cases."];
            const string indexDoc = "Every NodaTime.Test and NodaTime.TzdbCompiler.Test fixture, by NUnit full name, loaded on demand.";
            var tsIndex = new TypescriptWriter()
                .WriteLine("import type { ScenarioFixture } from \"./types.ts\";", emptyLineAfter: true)
                .DocComment(indexDoc)
                .OpenBlock("export const scenarioFixtures: Readonly<Record<string, () => Promise<ScenarioFixture>>> = {");
            foreach (var fixture in index)
                tsIndex.Property(Ts.Str(fixture.Name), $"async () => (await import({Ts.Str($"./{fixture.Path}.generated.ts")})).fixture");
            tsIndex.CloseBlock("};");
            output.Write(LangTarget.TypeScript.Test("scenarios/index"), Command, tsIndex, indexHeader);

            // Lazy top-level finals, not deferred imports: dart2js can't load those on Node.js.
            var dartIndex = new DartWriter()
                .WriteLine("import 'types.dart';", emptyLineAfter: true);
            for (var i = 0; i < index.Count; i++)
                dartIndex.WriteLine($"import {Dart.Str($"{index[i].Path}.generated.dart")} as f{i};");
            dartIndex.WriteLine()
                .DocComment("Every NodaTime.Test and NodaTime.TzdbCompiler.Test fixture, by NUnit full name, built on first use.")
                .OpenBlock("final Map<String, ScenarioFixture Function()> scenarioFixtures = {");
            for (var i = 0; i < index.Count; i++)
                dartIndex.Property(Dart.Str(index[i].Name), $"() => f{i}.fixture");
            dartIndex.CloseBlock("};");
            output.Write(LangTarget.Dart.Test("scenarios/index"), Command, dartIndex, indexHeader);

            foreach (var port in LangTarget.All)
            {
                WriteCultures(port);
                output.DeleteStale(port.TestRoot + "scenarios", port.GeneratedPattern);
            }
            Console.WriteLine($"{index.Count} fixtures, {testCount} test methods, {caseCount} cases.");
        }

        private static void CollectFixtures(ITest test, List<TestSuite> fixtures)
        {
            if (test is TestFixture fixture)
                fixtures.Add(fixture);
            foreach (var child in test.Tests)
                CollectFixtures(child, fixtures);
        }

        private FixtureModel ExtractFixture(TestSuite fixture, TestProject project)
        {
            var type = fixture.TypeInfo!.Type;
            var ns = type.Namespace ?? project.Namespace;
            var folder = ns == project.Namespace ? project.Folder : project.Folder + ns[(project.Namespace.Length + 1)..].Replace('.', '/') + "/";
            var fileName = ValueEncoder.NestedName(type) + (fixture.Arguments.Length > 0 ? "(" + string.Join(",", fixture.Arguments) + ")" : "");
            var fixtureExclusion = Exclusion(fixture.FullName);

            var tests = new List<TestModel>();
            foreach (var child in fixture.Tests.Cast<Test>().OrderBy(t => t.Method?.MethodInfo.MetadataToken ?? 0).ThenBy(t => t.Name, StringComparer.Ordinal))
            {
                var method = child.Method?.MethodInfo;
                if (method is null)
                    continue;
                var methodExclusion = fixtureExclusion ?? Exclusion($"{fixture.FullName}.{method.Name}") ?? "";
                var parameterized = child is ParameterizedMethodSuite;
                var testCases = child is ParameterizedMethodSuite suite ? suite.Tests.Cast<TestMethod>().ToList() : [(TestMethod) child];
                tests.Add(new TestModel(
                    method.Name,
                    _locations.MethodSource(method),
                    method.GetParameters().Select(p => $"{TypeName(p.ParameterType)} {p.Name}").ToList(),
                    method.DeclaringType != type ? ValueEncoder.NestedName(method.DeclaringType!) : null,
                    methodExclusion,
                    GetRunState(child),
                    methodExclusion.Length > 0 ? null : testCases.Select(c => ExtractCase(c, parameterized)).ToList()));
            }
            return new FixtureModel(fixture.FullName, folder + SafeFileName(fileName), _locations.TypeSource(type), fixtureExclusion, tests);
        }

        private CaseModel ExtractCase(TestMethod testCase, bool parameterized)
        {
            IReadOnlyList<EncodedValue> args;
            string? encodingError = null;
            try
            {
                args = testCase.Arguments.Select(_encoder.Encode).ToList();
            }
            catch (Exception e)
            {
                args = [];
                encodingError = $"{e.GetType().Name}: {e.Message}";
            }
            var parms = NodaTimeInternals.Parms(testCase) as TestCaseParameters;
            var hasExpected = parms is { HasExpectedResult: true };
            return new CaseModel(
                args,
                encodingError,
                hasExpected,
                hasExpected ? _encoder.Encode(parms!.ExpectedResult) : null,
                parameterized ? testCase.Properties.Get(PropertyNames.Description) as string : null,
                GetRunState(testCase));
        }

        private static RunStateModel? GetRunState(Test test)
        {
            var reason = test.Properties.Get(PropertyNames.SkipReason) as string ?? "";
            return test.RunState switch
            {
                RunState.Ignored or RunState.NotRunnable or RunState.Skipped => new RunStateModel(test.RunState, reason),
                RunState.Explicit => new RunStateModel(RunState.Explicit, null),
                _ => null,
            };
        }

        private static CodeWriter WriteFixture(CodeWriter body, FixtureModel fixture)
        {
            var depth = fixture.Path.Count(c => c == '/');
            var typesModule = depth == 0 ? "./types" : string.Concat(Enumerable.Repeat("../", depth)) + "types";
            body.OpenConstObject("fixture", "ScenarioFixture", typesModule, constant: false)
                .Property("name", body.Str(fixture.Name))
                .Property("source", body.Str(fixture.Source));
            if (fixture.Excluded is not null)
                body.Property("excluded", body.Str(fixture.Excluded));
            body.OpenBlock("tests: [");
            foreach (var test in fixture.Tests)
            {
                body.OpenObjectLine("ScenarioTest")
                    .Property("method", body.Str(test.Method))
                    .Property("source", body.Str(test.Source));
                if (test.Parameters.Count > 0)
                    body.Property("parameters", body.List(test.Parameters.Select(body.Str)));
                if (test.DeclaredIn is not null)
                    body.Property("declaredIn", body.Str(test.DeclaredIn));
                if (test.Excluded.Length > 0)
                    body.Property("excluded", body.Str(test.Excluded));
                body.Properties(new
                {
                    ignored = test.RunState?.Value(body, RunState.Ignored),
                    @explicit = test.RunState?.Value(body, RunState.Explicit),
                    notRunnable = test.RunState?.Value(body, RunState.NotRunnable),
                    skipped = test.RunState?.Value(body, RunState.Skipped),
                });
                if (test.Cases is null)
                {
                    body.Property("cases", "[]");
                }
                else
                {
                    body.OpenBlock("cases: [");
                    foreach (var testCase in test.Cases)
                    {
                        var parts = new
                        {
                            args = body.List(testCase.Args.Select(body.Value)),
                            encodingError = testCase.EncodingError is null ? null : body.Str(testCase.EncodingError),
                            expected = testCase.HasExpected ? body.Value(testCase.Expected!) : null,
                            description = testCase.Description is null ? null : body.Str(testCase.Description),
                            ignored = testCase.RunState?.Value(body, RunState.Ignored),
                            @explicit = testCase.RunState?.Value(body, RunState.Explicit),
                            notRunnable = testCase.RunState?.Value(body, RunState.NotRunnable),
                            skipped = testCase.RunState?.Value(body, RunState.Skipped),
                            // The Dart harness skips the case on dart2js.
                            dart2js = body switch
                            {
                                TypescriptWriter => null,
                                DartWriter => testCase.ExceedsDoublePrecision ? body.Bool(false) : null,
                                _ => body.ThrowUnknown<string?>(),
                            },
                        };
                        switch (body)
                        {
                            case TypescriptWriter:
                                body.WriteLine(body.Object("ScenarioCase", parts) + ",");
                                break;
                            case DartWriter:
                                body.WriteLine((testCase.IsDartConstant ? "const " : "") + body.Object("ScenarioCase", parts) + ",");
                                break;
                            default:
                                body.ThrowUnknown();
                                break;
                        }
                    }
                    body.CloseBlock("],");
                }
                body.CloseObjectLine();
            }
            return body.CloseBlock("],")
                .CloseConstObject();
        }

        /// <summary>Cultures by identity (NodaTime.Test modifies some), and well-known static instances.</summary>
        private EncodedValue? Override(object value)
        {
            if (value is CultureInfo culture)
            {
                var key = CultureKey(culture);
                if (!_cultures.ContainsKey(key))
                    _cultures[key] = culture;
                return EncodedValue.Tag(nameof(CultureInfo), new { name = EncodedValue.String(culture.Name), key = EncodedValue.String(key) });
            }
            if (value is string || value.GetType().IsValueType || value.GetType().IsArray)
                return null;
            if (value is NodaTime.Period or NodaTime.CalendarSystem or NodaTime.Calendars.Era or NodaTime.DateTimeZone or NodaTime.TimeZones.ZoneInterval or NodaTime.DateInterval)
                return null;
            if (_statics.TryGet(value, out var reference))
                return EncodedValue.Tag("Static", new
                {
                    @ref = EncodedValue.String(reference.Name),
                    type = EncodedValue.String(ValueEncoder.NestedName(value.GetType())),
                });
            return null;
        }

        /// <summary>"Cultures.X" for NodaTime.Test's test cultures, the name for standard ones, else "name#hash".</summary>
        private string CultureKey(CultureInfo culture)
        {
            if (_statics.TryGet(culture, out var reference) && reference.OuterType.Name == "Cultures")
                return reference.Name;
            var data = CultureSerializer.Serialize(culture);
            var standard = CultureSerializer.Serialize(CultureInfo.GetCultureInfo(culture.Name));
            if (data == standard)
                return culture.Name;
            var hash = System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(data));
            return $"{culture.Name}#{Convert.ToHexStringLower(hash)[..8]}";
        }

        private void WriteCultures(LangTarget langTarget)
        {
            const string doc = "Every culture the scenarios use, by the `key` of its encoded value.";
            var body = langTarget.NewWriter();
            switch (body)
            {
                case TypescriptWriter:
                    body.WriteLine("import type { CultureData } from \"../../src/noda-js/Globalization/NodaCultureInfo.ts\";", emptyLineAfter: true)
                        .DocComment(doc)
                        .OpenBlock("export const scenarioCultures: Readonly<Record<string, CultureData>> = {");
                    break;
                case DartWriter:
                    body.WriteLine("import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';", emptyLineAfter: true)
                        .DocComment(doc.ReplaceLineEndings(" "))
                        .OpenBlock("final Map<String, CultureData> scenarioCultures = {");
                    break;
                default:
                    body.ThrowUnknown();
                    break;
            }
            foreach (var culture in _cultures)
            {
                body.AppendIndent().AppendOnLine($"{body.Str(culture.Key)}: ");
                CultureSerializer.Write(body, culture.Value);
                body.AppendOnLine(",").AppendNewline();
            }
            body.CloseBlock("};");
            output.Write(langTarget.Test("scenarios/cultures"), Command, body,
                ["Source: ICU/CLDR via .NET (Unicode License; see NOTICE.txt), as NodaTime.Test modifies it."]);
        }

        private string? Exclusion(string name)
        {
            foreach (var exclusion in _exclusions)
            {
                var rule = exclusion.Rule;
                var matches = rule.EndsWith('*') ? name.StartsWith(rule[..^1], StringComparison.Ordinal) : name == rule;
                if (matches)
                    return exclusion.Reason.Length > 0 ? exclusion.Reason : "excluded";
            }
            return null;
        }

        private static List<ExclusionRule> LoadExclusions() =>
            File.ReadAllLines(Path.Combine(ToolEnvironment.RepoRoot, "tools", "scenario-exclusions.txt"))
                .Select(line => line.Trim())
                .Where(line => line.Length > 0 && !line.StartsWith('#'))
                .Select(line =>
                {
                    var hash = line.IndexOf('#');
                    var rule = (hash >= 0 ? line[..hash] : line).Trim();
                    var reason = hash >= 0 ? line[(hash + 1)..].Trim() : "";
                    return new ExclusionRule(rule, reason);
                })
                .ToList();

        private static string SafeFileName(string name) =>
            string.Concat(name.Select(c => Path.GetInvalidFileNameChars().Contains(c) || c == '"' ? '_' : c));

        private static string TypeName(Type type)
        {
            if (type.IsByRef) 
                return TypeName(type.GetElementType()!);
            if (type.IsArray) 
                return TypeName(type.GetElementType()!) + "[]";
            if (Nullable.GetUnderlyingType(type) is { } underlying) 
                return TypeName(underlying) + "?";
            if (type.IsGenericType)
                return $"{type.Name[..type.Name.IndexOf('`')]}<{string.Join(", ", type.GetGenericArguments().Select(TypeName))}>";
            return type.FullName switch
            {
                "System.Int32" => "int",
                "System.Int64" => "long",
                "System.Double" => "double",
                "System.String" => "string",
                "System.Boolean" => "bool",
                "System.Object" => "object",
                "System.Char" => "char",
                _ => type.Name,
            };
        }
    }

    /// <summary>Names of static instances ("Resolvers.StrictResolver", "Cultures.GenitiveNameTestCulture").</summary>
    internal sealed class StaticReferences
    {
        private readonly Dictionary<object, StaticReference> _references = new(ReferenceEqualityComparer.Instance);

        private sealed record StaticMember(string Name, Func<object?> Get);

        public StaticReferences(IEnumerable<Assembly> assemblies)
        {
            const BindingFlags flags = BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
            foreach (var assembly in assemblies)
                foreach (var type in assembly.GetTypes().Where(t => !t.ContainsGenericParameters && !t.Name.Contains('<')).OrderBy(t => t.FullName, StringComparer.Ordinal))
                {
                    var members = type.GetFields(flags)
                        .Where(f => !f.IsLiteral && !f.Name.Contains('<'))
                        .Select(f => new StaticMember(f.Name, () => f.GetValue(null)))
                        .Concat(type.GetProperties(flags)
                            .Where(p => p.GetMethod is not null && p.GetIndexParameters().Length == 0)
                            .Select(p => new StaticMember(p.Name, () => p.GetValue(null))));
                    foreach (var member in members)
                    {
                        object? value;
                        try
                        {
                            value = member.Get();
                        }
                        catch
                        {
                            continue;
                        }
                        if (value is null || value is string || value.GetType().IsValueType)
                            continue;
                        // First name wins: NodaTime's before the tests'.
                        _references.TryAdd(value, new StaticReference(type, member.Name));
                    }
                }
        }

        public bool TryGet(object value, out StaticReference reference) => _references.TryGetValue(value, out reference!);
    }

    /// <summary>A static field or property holding an instance.</summary>
    internal sealed record StaticReference(Type Type, string Member)
    {
        /// <summary>"Resolvers.StrictResolver".</summary>
        public string Name => $"{ValueEncoder.NestedName(Type)}.{Member}";

        /// <summary>The outermost type declaring the member.</summary>
        public Type OuterType
        {
            get
            {
                var type = Type;
                while (type.DeclaringType is not null)
                    type = type.DeclaringType;
                return type;
            }
        }
    }

    /// <summary>Test methods' source file and line, from the PDBs.</summary>
    internal sealed class SourceLocations
    {
        private readonly Dictionary<Assembly, MetadataReader> _readers = [];
        private readonly string _root = ToolEnvironment.NodaTimeRoot;

        public SourceLocations(IEnumerable<Assembly> assemblies)
        {
            foreach (var assembly in assemblies)
            {
                var pdb = Path.ChangeExtension(assembly.Location, ".pdb");
                if (File.Exists(pdb))
                    _readers[assembly] = MetadataReaderProvider.FromPortablePdbStream(File.OpenRead(pdb)).GetMetadataReader();
            }
        }

        private sealed record SourceLocation(string File, int Line);

        /// <summary>"path:line", or "" without a PDB.</summary>
        public string MethodSource(MethodInfo method) =>
            Location(method) is { } location ? $"{location.File}:{location.Line}" : "";

        private SourceLocation? Location(MethodInfo method)
        {
            if (!_readers.TryGetValue(method.Module.Assembly, out var reader))
                return null;
            var handle = MetadataTokens.MethodDefinitionHandle(method.MetadataToken);
            var info = reader.GetMethodDebugInformation(handle);
            foreach (var point in info.GetSequencePoints())
                if (!point.IsHidden)
                    return new SourceLocation(Relative(reader.GetString(reader.GetDocument(point.Document).Name)), point.StartLine);
            return null;
        }

        public string TypeSource(Type type)
        {
            const BindingFlags flags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
            var files = type.GetMethods(flags)
                .Concat<MethodBase>(type.GetConstructors(flags))
                .OfType<MethodInfo>()
                .Select(Location)
                .OfType<SourceLocation>()
                .Select(l => l.File)
                .Distinct()
                .Order(StringComparer.Ordinal)
                .ToList();
            return string.Join(", ", files);
        }

        private string Relative(string path) => Path.GetRelativePath(_root, path).Replace('\\', '/');
    }
}
