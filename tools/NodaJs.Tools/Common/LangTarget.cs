namespace NodaJs.Tools.Common;

/// <summary>
/// A language target: where its generated files go, and its writer.
/// </summary>
public sealed class LangTarget
{
    /// <summary>
    /// Target for TypeScript: "ts/src/noda-js/" and "ts/test/", ".ts", and <see cref="TypescriptWriter"/>.
    /// </summary>
    public static readonly LangTarget TypeScript = 
        new("TypeScript", "ts/src/noda-js/", "ts/test/", ".ts", () => new TypescriptWriter());

    /// <summary>
    /// Target for Dart: "dart/noda_dart/lib/src/" and "dart/noda_dart/test/", ".dart", and <see cref="DartWriter"/>.
    /// </summary>
    public static readonly LangTarget Dart = 
        new("Dart", "dart/noda_dart/lib/src/", "dart/noda_dart/test/", ".dart", () => new DartWriter());

    public static IReadOnlyList<LangTarget> All { get; } = [TypeScript, Dart];

    private readonly Func<CodeWriter> _newWriter;

    private LangTarget(string name, string sourceRoot, string testRoot, string extension, Func<CodeWriter> newWriter)
    {
        Name = name;
        SourceRoot = sourceRoot;
        TestRoot = testRoot;
        Extension = extension;
        _newWriter = newWriter;
    }

    public string Name { get; }

    public string SourceRoot { get; }

    public string TestRoot { get; }

    public string Extension { get; }

    public string GeneratedExtension => ".generated" + Extension;

    public string GeneratedPattern => "*" + GeneratedExtension;

    /// <summary><c>Source("Text/X")</c> → "ts/src/noda-js/Text/X.generated.ts".</summary>
    public string Source(string path) => SourceRoot + path + GeneratedExtension;

    /// <summary><c>Test("golden/x")</c> → "ts/test/golden/x.generated.ts".</summary>
    public string Test(string path) => TestRoot + path + GeneratedExtension;

    public CodeWriter NewWriter() => _newWriter();

    public override string ToString() => Name;
}
