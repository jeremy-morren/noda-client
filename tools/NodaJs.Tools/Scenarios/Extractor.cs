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
    /// The <c>scenarios</c> command: every NUnit test in NodaTime.Test and NodaTime.TzdbCompiler.Test as a test
    /// scenario: the fixture, method, source location, and (for parameterized tests) every case's arguments and expected
    /// result. Cases are enumerated by NUnit itself (DefaultTestAssemblyBuilder), so TestCase, TestCaseSource, Values,
    /// inherited tests, etc. come out exactly as NUnit would run them. Re-running after a NodaTime upgrade picks up new
    /// tests.
    /// Output: test/scenarios/&lt;namespace path&gt;/&lt;Fixture&gt;.generated.ts (NodaTime.TzdbCompiler.Test's under
    /// test/scenarios/TzdbCompiler/), test/scenarios/index.generated.ts and test/scenarios/cultures.generated.ts (data
    /// for every culture the cases refer to).
    /// </summary>
    internal sealed class Extractor(GeneratedFiles output)
    {
        private const string Command = "scenarios";
        private static readonly Assembly TestAssembly = typeof(NodaTime.Test.Text.PatternTestBase<>).Assembly;
        private static readonly Assembly CompilerTestAssembly = typeof(NodaTime.TzdbCompiler.Test.ProgramTest).Assembly;
        private static readonly Assembly NodaTimeAssembly = typeof(NodaTime.Instant).Assembly;
        private static readonly Assembly TestingAssembly = typeof(NodaTime.Testing.FakeClock).Assembly;
        private static readonly Assembly CompilerAssembly = typeof(NodaTime.TzdbCompiler.Tzdb.TzdbDatabase).Assembly;

        /// <summary>
        /// The test assemblies, each with its root namespace and the folder under test/scenarios its fixtures go to
        /// (sub-namespaces become sub-folders).
        /// </summary>
        private static readonly (Assembly Assembly, string Namespace, string Folder)[] TestProjects =
        [
            (TestAssembly, "NodaTime.Test", ""),
            (CompilerTestAssembly, "NodaTime.TzdbCompiler.Test", "TzdbCompiler/"),
        ];

        // The compiler's assemblies come last, so the names of NodaTime's own instances don't change.
        private readonly StaticReferences _statics = new([NodaTimeAssembly, TestingAssembly, TestAssembly, CompilerAssembly, CompilerTestAssembly]);
        private readonly SortedDictionary<string, CultureInfo> _cultures = new(StringComparer.Ordinal);
        private readonly SourceLocations _locations = new(TestProjects.Select(p => p.Assembly));
        private readonly List<(string Name, string Rule, string Reason)> _exclusions = LoadExclusions();
        private TsValueEncoder _encoder = null!;

        public void Run()
        {
            _encoder = new TsValueEncoder { Override = Override };
            // Test data classes, and the compiler's (mostly internal) types, are encoded field by field.
            _encoder.StructuralAssemblies.UnionWith([TestAssembly, CompilerTestAssembly, CompilerAssembly]);

            var fixtures = new List<(TestSuite Fixture, string Namespace, string Folder)>();
            foreach (var (assembly, ns, folder) in TestProjects)
            {
                var root = new DefaultTestAssemblyBuilder().Build(assembly, new Dictionary<string, object>());
                var found = new List<TestSuite>();
                CollectFixtures(root, found);
                fixtures.AddRange(found.Select(f => (f, ns, folder)));
            }

            var index = new List<(string Name, string Module)>();
            int caseCount = 0, testCount = 0;
            foreach (var (fixture, ns, folder) in fixtures.OrderBy(f => f.Fixture.FullName, StringComparer.Ordinal))
            {
                var (relativePath, body, tests, cases) = WriteFixture(fixture, ns, folder);
                output.Write(relativePath, Command, body);
                index.Add((fixture.FullName, "./" + Path.GetRelativePath("test/scenarios", relativePath).Replace('\\', '/')));
                testCount += tests;
                caseCount += cases;
            }

            var indexBody = new TypescriptWriter()
                .WriteLine("import type { ScenarioFixture } from \"./types.ts\";", emptyLineAfter: true)
                .DocComment("Every NodaTime.Test and NodaTime.TzdbCompiler.Test fixture, by NUnit full name, loaded on demand.")
                .OpenBlock("export const scenarioFixtures: Readonly<Record<string, () => Promise<ScenarioFixture>>> = {");
            foreach (var (name, module) in index)
                indexBody.Property(Ts.Str(name), $"async () => (await import({Ts.Str(module)})).fixture");
            indexBody.CloseBlock("};");
            output.Write("test/scenarios/index.generated.ts", Command, indexBody,
                [$"{index.Count} fixtures, {testCount} test methods, {caseCount} cases."]);

            WriteCultures();
            output.DeleteStale("test/scenarios");
            Console.WriteLine($"{index.Count} fixtures, {testCount} test methods, {caseCount} cases.");
        }

        private static void CollectFixtures(ITest test, List<TestSuite> fixtures)
        {
            if (test is TestFixture fixture)
                fixtures.Add(fixture);
            foreach (var child in test.Tests)
                CollectFixtures(child, fixtures);
        }

        private (string Path, TypescriptWriter Body, int Tests, int Cases) WriteFixture(TestSuite fixture, string rootNamespace, string rootFolder)
        {
            var type = fixture.TypeInfo!.Type;
            var ns = type.Namespace ?? rootNamespace;
            var folder = ns == rootNamespace ? rootFolder : rootFolder + ns[(rootNamespace.Length + 1)..].Replace('.', '/') + "/";
            var fileName = TsValueEncoder.NestedName(type) + (fixture.Arguments.Length > 0 ? "(" + string.Join(",", fixture.Arguments) + ")" : "");
            var relativePath = $"test/scenarios/{folder}{SafeFileName(fileName)}.generated.ts";
            var typesImport = string.Concat(Enumerable.Repeat("../", folder.Count(c => c == '/'))) + "types.ts";
            if (!typesImport.StartsWith('.'))
                typesImport = "./" + typesImport;

            var body = new TypescriptWriter()
                .WriteLine($"import type {{ ScenarioFixture }} from {Ts.Str(typesImport)};", emptyLineAfter: true)
                .OpenBlock("export const fixture: ScenarioFixture = {")
                .Property("name", Ts.Str(fixture.FullName))
                .Property("source", Ts.Str(_locations.TypeSource(type)));
            var fixtureExclusion = Exclusion(fixture.FullName);
            if (fixtureExclusion is not null)
                body.Property("excluded", Ts.Str(fixtureExclusion));
            body.OpenBlock("tests: [");

            int tests = 0, cases = 0;
            // Each child is a TestMethod (simple test) or a ParameterizedMethodSuite of TestMethods.
            foreach (var child in fixture.Tests.Cast<Test>().OrderBy(t => t.Method?.MethodInfo.MetadataToken ?? 0).ThenBy(t => t.Name, StringComparer.Ordinal))
            {
                var method = child.Method?.MethodInfo;
                if (method is null)
                    continue;
                tests++;
                var methodExclusion = fixtureExclusion ?? Exclusion($"{fixture.FullName}.{method.Name}") ?? "";
                body.OpenBlock("{")
                    .Property("method", Ts.Str(method.Name))
                    .Property("source", Ts.Str(_locations.MethodSource(method)));
                var parameters = method.GetParameters();
                if (parameters.Length > 0)
                    body.Property("parameters", $"[{string.Join(", ", parameters.Select(p => Ts.Str($"{TypeName(p.ParameterType)} {p.Name}")))}]");
                if (method.DeclaringType != type)
                    body.Property("declaredIn", Ts.Str(TsValueEncoder.NestedName(method.DeclaringType!)));
                if (methodExclusion.Length > 0)
                    body.Property("excluded", Ts.Str(methodExclusion));
                if (RunStateProperty(child) is { } runState)
                    body.WriteLine(runState + ",");
                var testCases = child is ParameterizedMethodSuite suite ? suite.Tests.Cast<TestMethod>().ToList() : [(TestMethod) child];
                if (methodExclusion.Length > 0)
                {
                    body.Property("cases", "[]");
                }
                else
                {
                    body.OpenBlock("cases: [");
                    foreach (var testCase in testCases)
                    {
                        cases++;
                        body.WriteLine(EncodeCase(testCase, child is ParameterizedMethodSuite) + ",");
                    }
                    body.CloseBlock("],");
                }
                body.CloseBlock("},");
            }
            body.CloseBlock("],")
                .CloseBlock("};");
            return (relativePath, body, tests, cases);
        }

        private string EncodeCase(TestMethod testCase, bool parameterized)
        {
            var parts = new List<string>();
            string args;
            try
            {
                args = "[" + string.Join(", ", testCase.Arguments.Select(_encoder.Encode)) + "]";
            }
            catch (Exception e)
            {
                args = "[]";
                parts.Add($"encodingError: {Ts.Str($"{e.GetType().Name}: {e.Message}")}");
            }
            parts.Insert(0, $"args: {args}");
            // TestMethod.Parms is internal to NUnit: see NodaTimeInternals.
            if (NodaTimeInternals.Parms(testCase) is TestCaseParameters { HasExpectedResult: true } parms)
                parts.Add($"expected: {_encoder.Encode(parms.ExpectedResult)}");
            if (parameterized && testCase.Properties.Get(PropertyNames.Description) is string description)
                parts.Add($"description: {Ts.Str(description)}");
            if (RunStateProperty(testCase) is { } runState)
                parts.Add(runState);
            return "{ " + string.Join(", ", parts) + " }";
        }

        /// <summary>The run state as an object property (<c>ignored: "reason"</c>), or null if the test is runnable.</summary>
        private static string? RunStateProperty(Test test)
        {
            var reason = Ts.Str(test.Properties.Get(PropertyNames.SkipReason) as string ?? "");
            return test.RunState switch
            {
                RunState.Ignored => $"ignored: {reason}",
                RunState.Explicit => "explicit: true",
                RunState.NotRunnable => $"notRunnable: {reason}",
                RunState.Skipped => $"skipped: {reason}",
                _ => null,
            };
        }

        /// <summary>
        /// Value encoding specific to the test assembly: cultures (by identity, so NodaTime.Test's custom
        /// cultures are distinguished from the standard ones) and well-known static instances.
        /// </summary>
        private string? Override(object value)
        {
            if (value is CultureInfo culture)
            {
                var key = CultureKey(culture);
                if (!_cultures.ContainsKey(key))
                    _cultures[key] = culture;
                return TsValueEncoder.Tag(nameof(CultureInfo), ("name", Ts.Str(culture.Name)), ("key", Ts.Str(key)));
            }
            if (value is string || value.GetType().IsValueType || value.GetType().IsArray)
                return null;
            if (value is NodaTime.Period or NodaTime.CalendarSystem or NodaTime.Calendars.Era or NodaTime.DateTimeZone or NodaTime.TimeZones.ZoneInterval or NodaTime.DateInterval)
                return null; // encoded structurally
            if (_statics.TryGetName(value, out var staticName))
                return TsValueEncoder.Tag("Static", ("ref", Ts.Str(staticName)), ("type", Ts.Str(TsValueEncoder.NestedName(value.GetType()))));
            return null;
        }

        /// <summary>
        /// A stable key for a culture: "Cultures.X" for NodaTime.Test's named test cultures, the culture name for
        /// standard cultures, and "name#hash" for cultures a test modified inline (so they don't collide with
        /// the standard culture of the same name).
        /// </summary>
        private string CultureKey(CultureInfo culture)
        {
            if (_statics.TryGetName(culture, out var name) && name.StartsWith("Cultures.", StringComparison.Ordinal))
                return name;
            var data = CultureSerializer.Serialize(culture);
            var standard = CultureSerializer.Serialize(CultureInfo.GetCultureInfo(culture.Name));
            if (data == standard)
                return culture.Name;
            var hash = System.Security.Cryptography.SHA256.HashData(Encoding.UTF8.GetBytes(data));
            return $"{culture.Name}#{Convert.ToHexStringLower(hash)[..8]}";
        }

        private void WriteCultures()
        {
            var body = new TypescriptWriter()
                .WriteLine("import type { CultureData } from \"../../src/noda-js/Globalization/NodaCultureInfo.ts\";", emptyLineAfter: true)
                .DocComment("""
                    Every culture the scenarios refer to, keyed by the `key` of their encoded value: the culture name,
                    or "Cultures.X" for NodaTime.Test's custom test cultures (src/NodaTime.Test/Text/Cultures.cs).
                    """)
                .OpenBlock("export const scenarioCultures: Readonly<Record<string, CultureData>> = {");
            foreach (var (key, culture) in _cultures)
            {
                body.AppendIndent().AppendOnLine($"{Ts.Str(key)}: ");
                CultureSerializer.Write(body, culture);
                body.AppendOnLine(",").AppendNewline();
            }
            body.CloseBlock("};");
            output.Write("test/scenarios/cultures.generated.ts", Command, body,
                ["Culture data comes from ICU/CLDR via .NET (Unicode License; see NOTICE.txt), modified by NodaTime.Test where it says so."]);
        }

        private string? Exclusion(string name)
        {
            foreach (var (_, rule, reason) in _exclusions)
            {
                var matches = rule.EndsWith('*') ? name.StartsWith(rule[..^1], StringComparison.Ordinal) : name == rule;
                if (matches)
                    return reason.Length > 0 ? reason : "excluded";
            }
            return null;
        }

        private static List<(string, string, string)> LoadExclusions() =>
            File.ReadAllLines(Path.Combine(ToolEnvironment.RepoRoot, "tools", "scenario-exclusions.txt"))
                .Select(line => line.Trim())
                .Where(line => line.Length > 0 && !line.StartsWith('#'))
                .Select(line =>
                {
                    var hash = line.IndexOf('#');
                    var rule = (hash >= 0 ? line[..hash] : line).Trim();
                    var reason = hash >= 0 ? line[(hash + 1)..].Trim() : "";
                    return (line, rule, reason);
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

    /// <summary>
    /// Names for well-known static instances (e.g. "Resolvers.StrictResolver", "LocalDatePattern.Iso",
    /// "Cultures.GenitiveNameTestCulture"), found by reflecting over static fields and properties.
    /// </summary>
    internal sealed class StaticReferences
    {
        private readonly Dictionary<object, string> _names = new(ReferenceEqualityComparer.Instance);

        public StaticReferences(IEnumerable<Assembly> assemblies)
        {
            const BindingFlags flags = BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
            foreach (var assembly in assemblies)
                foreach (var type in assembly.GetTypes().Where(t => !t.ContainsGenericParameters && !t.Name.Contains('<')).OrderBy(t => t.FullName, StringComparer.Ordinal))
                {
                    var members = type.GetFields(flags)
                        .Where(f => !f.IsLiteral && !f.Name.Contains('<'))
                        .Select(f => (f.Name, Get: (Func<object?>) (() => f.GetValue(null))))
                        .Concat(type.GetProperties(flags)
                            .Where(p => p.GetMethod is not null && p.GetIndexParameters().Length == 0)
                            .Select(p => (p.Name, Get: (Func<object?>) (() => p.GetValue(null)))));
                    foreach (var (name, get) in members)
                    {
                        object? value;
                        try
                        {
                            value = get();
                        }
                        catch
                        {
                            continue;
                        }
                        if (value is null || value is string || value.GetType().IsValueType)
                            continue;
                        // First name wins; public NodaTime members are visited before test members.
                        _names.TryAdd(value, $"{TsValueEncoder.NestedName(type)}.{name}");
                    }
                }
        }

        public bool TryGetName(object value, out string name) => _names.TryGetValue(value, out name!);
    }

    /// <summary>
    /// Source file and line of test methods, from the test assemblies' portable PDBs.
    /// </summary>
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

        public string MethodSource(MethodInfo method)
        {
            if (!_readers.TryGetValue(method.Module.Assembly, out var reader))
                return "";
            var handle = MetadataTokens.MethodDefinitionHandle(method.MetadataToken);
            var info = reader.GetMethodDebugInformation(handle);
            foreach (var point in info.GetSequencePoints())
                if (!point.IsHidden)
                    return $"{Relative(reader.GetString(reader.GetDocument(point.Document).Name))}:{point.StartLine}";
            return "";
        }

        public string TypeSource(Type type)
        {
            const BindingFlags flags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly;
            var files = type.GetMethods(flags)
                .Concat<MethodBase>(type.GetConstructors(flags))
                .OfType<MethodInfo>()
                .Select(MethodSource)
                .Where(s => s.Length > 0)
                .Select(s => s[..s.LastIndexOf(':')])
                .Distinct()
                .Order(StringComparer.Ordinal)
                .ToList();
            return string.Join(", ", files);
        }

        private string Relative(string path) => Path.GetRelativePath(_root, path).Replace('\\', '/');
    }
}
