using System.Globalization;
using System.Reflection;
using System.Runtime.InteropServices;

namespace NodaJs.Tools.Common;

public static class ToolEnvironment
{
    public static string RepoRoot { get; private set; } = FindRepoRoot(AppContext.BaseDirectory);

    /// <summary>A commit or tag (tools/Directory.Packages.props).</summary>
    public static string NodaTimeRef { get; } = Metadata("NodaTimeRef");

    public static string NodaTimeHead { get; } = Metadata("NodaTimeHead");

    public static string NodaTimeVersion => NodaTimeHead[..8];

    public static string NodaTimeRoot => Path.Combine(RepoRoot, ".nodatime", NodaTimeRef);

    /// <summary>Test data both ports read (repo-relative): fixtures, and the <c>system-zones</c> export.</summary>
    public const string TestData = "testdata";

    private static string Metadata(string key) => typeof(ToolEnvironment).Assembly
        .GetCustomAttributes<AssemblyMetadataAttribute>()
        .Single(attribute => attribute.Key == key)
        .Value!;

    public static string DotNetVersion => RuntimeInformation.FrameworkDescription.Replace(".NET ", "");

    // No public API for it.
    public static string IcuVersion
    {
        get
        {
            var packed = NodaTimeInternals.GetIcuVersion(null);
            if (packed != 0)
                return $"{(packed >> 24) & 0xff}.{(packed >> 16) & 0xff}.{(packed >> 8) & 0xff}.{packed & 0xff}";
            return "unknown (not ICU)";
        }
    }

    public static string Describe() =>
        $"NodaTime {NodaTimeVersion}, .NET {DotNetVersion}, ICU {IcuVersion}";

    public static void UseRepoRoot(string? path)
    {
        if (path is not null)
            RepoRoot = Path.GetFullPath(path);
    }

    private static string FindRepoRoot(string start)
    {
        for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
        {
            if (File.Exists(Path.Combine(dir.FullName, "version.txt")) &&
                File.Exists(Path.Combine(dir.FullName, "tools", "Directory.Packages.props")))
                return dir.FullName;
        }
        return Directory.GetCurrentDirectory();
    }

    /// <summary>Generated culture data must not depend on the host (NLS, invariant mode).</summary>
    public static void RequireIcu()
    {
        if (IcuVersion.StartsWith("unknown", StringComparison.Ordinal))
            throw new InvalidOperationException("ICU globalization is required (app-local ICU is configured in the project).");
        if (CultureInfo.InvariantCulture.Name != "")
            throw new InvalidOperationException("Unexpected invariant culture name.");
    }
}
