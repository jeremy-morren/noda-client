using System.Globalization;
using System.Reflection;
using System.Runtime.InteropServices;

namespace NodaJs.Tools.Common;

/// <summary>
/// Locations and versions shared by the tools.
/// </summary>
public static class ToolEnvironment
{
    /// <summary>The noda-js repository root (the directory containing package.json and tools/).</summary>
    public static string RepoRoot { get; private set; } = FindRepoRoot(AppContext.BaseDirectory);

    /// <summary>
    /// The pinned NodaTime version (also its git tag): NodaTimeVersion in tools/Directory.Packages.props, which the
    /// build embeds as assembly metadata.
    /// </summary>
    public static string NodaTimeTag { get; } = typeof(ToolEnvironment).Assembly
        .GetCustomAttributes<AssemblyMetadataAttribute>()
        .Single(attribute => attribute.Key == "NodaTimeVersion")
        .Value!;

    /// <summary>The local clone of NodaTime at the pinned tag.</summary>
    public static string NodaTimeRoot => Path.Combine(RepoRoot, ".nodatime", NodaTimeTag);

    public static string DotNetVersion => RuntimeInformation.FrameworkDescription.Replace(".NET ", "");

    /// <summary>
    /// The ICU version .NET is using, e.g. "72.1.0.3". Read from the runtime's internal interop
    /// (there's no public API for it).
    /// </summary>
    public static string IcuVersion
    {
        get
        {
            var interop = typeof(object).Assembly.GetType("Interop+Globalization");
            var method = interop?.GetMethod("GetICUVersion", BindingFlags.NonPublic | BindingFlags.Static);
            if (method?.Invoke(null, null) is int packed && packed != 0)
                return $"{(packed >> 24) & 0xff}.{(packed >> 16) & 0xff}.{(packed >> 8) & 0xff}.{packed & 0xff}";
            return "unknown (not ICU)";
        }
    }

    /// <summary>Checks we're running with ICU globalization and the pinned NodaTime, and returns a summary.</summary>
    public static string Describe() =>
        $"NodaTime {NodaTimeTag}, .NET {DotNetVersion}, ICU {IcuVersion}";

    public static void UseRepoRoot(string? path)
    {
        if (path is not null)
            RepoRoot = Path.GetFullPath(path);
    }

    private static string FindRepoRoot(string start)
    {
        for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
        {
            if (File.Exists(Path.Combine(dir.FullName, "package.json")) &&
                File.Exists(Path.Combine(dir.FullName, "tools", "Directory.Packages.props")))
                return dir.FullName;
        }
        return Directory.GetCurrentDirectory();
    }

    /// <summary>
    /// Fails fast if globalization isn't ICU-backed (e.g. NLS on old Windows, or invariant mode),
    /// since generated culture data must not depend on the host.
    /// </summary>
    public static void RequireIcu()
    {
        if (IcuVersion.StartsWith("unknown", StringComparison.Ordinal))
            throw new InvalidOperationException("ICU globalization is required (app-local ICU is configured in the project).");
        if (CultureInfo.InvariantCulture.Name != "")
            throw new InvalidOperationException("Unexpected invariant culture name.");
    }
}
