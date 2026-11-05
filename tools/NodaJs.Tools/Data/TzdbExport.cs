using System.Reflection;
using System.Security.Cryptography;
using NodaJs.Tools.Common;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>
/// The bundled tzdb: an NZD file (NodaTime's compiled tz format), as base64 in a TS module. Sources:
/// <list type="bullet">
/// <item>"compile" (default): compile it ourselves with NodaTime's own TzdbCompiler, from the latest IANA
/// release and the latest CLDR windowsZones.xml, so new tz data doesn't wait for a nodatime.org release.</item>
/// <item>"latest": the NZD published by nodatime.org (https://nodatime.org/tzdb/latest.txt).</item>
/// <item>"embedded": the Tzdb.nzd embedded in the pinned NodaTime build (deterministic, offline).</item>
/// </list>
/// </summary>
internal static class TzdbExport
{
    public static async Task Run(GeneratedFiles output, string source, string? tzdataSource, string? cldrSource)
    {
        var (data, origin) = source switch
        {
            "compile" => await Compile(tzdataSource ?? Downloads.IanaTzdataLatest, cldrSource),
            "latest" => await DownloadLatest(),
            "embedded" => Embedded(),
            _ => throw new ArgumentException($"Unknown tzdb source '{source}' (expected compile, latest or embedded)"),
        };

        // Check NodaTime can load and validate it before we bundle it.
        var tzdb = TzdbDateTimeZoneSource.FromStream(new MemoryStream(data));
        tzdb.Validate();
        var sha256 = Convert.ToHexStringLower(SHA256.HashData(data));

        var body = new TypescriptWriter()
            .DocComment("The tzdb release in the bundled data, e.g. \"2025b\".")
            .WriteLine($"export const tzdbVersion = {Ts.Str(tzdb.TzdbVersion)};", emptyLineAfter: true)
            .DocComment("NodaTime's version ID for the bundled data.")
            .WriteLine($"export const versionId = {Ts.Str(tzdb.VersionId)};", emptyLineAfter: true)
            .DocComment("SHA-256 of the NZD bytes.")
            .WriteLine($"export const sha256 = {Ts.Str(sha256)};", emptyLineAfter: true)
            .DocComment("Number of canonical zone IDs.")
            .WriteLine($"export const zoneCount = {tzdb.CanonicalIdMap.Values.Distinct().Count()};", emptyLineAfter: true)
            .DocComment($"The NZD file ({data.Length} bytes), base64-encoded.")
            .WriteLine($"export const nzdBase64 = {Ts.Str(Convert.ToBase64String(data))};");
        output.Write("src/noda-js/TimeZones/TzdbBundledData.generated.ts", "tzdb", body,
            [$"Source: {origin}", "tz data is public domain; the CLDR Windows mapping in it is under the Unicode License (see NOTICE.txt)."]);
    }

    /// <summary>
    /// Runs NodaTime.TzdbCompiler (from the pinned NodaTime clone) on IANA tz data and CLDR windowsZones.xml.
    /// The compiler reloads and validates its output itself.
    /// </summary>
    private static async Task<(byte[], string)> Compile(string tzdata, string? cldrSource)
    {
        var (windowsZones, cldrOrigin) = await Downloads.CldrWindowsZones(cldrSource);
        var work = Path.Combine(Path.GetTempPath(), "noda-js-tzdb-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        try
        {
            var windowsZonesPath = Path.Combine(work, "windowsZones.xml");
            var nzdPath = Path.Combine(work, "tzdb.nzd");
            windowsZones.Save(windowsZonesPath);
            var tzdataOrigin = tzdata;
            tzdata = await LocalVersionedTarball(tzdata, work);

            var program = Type.GetType("NodaTime.TzdbCompiler.Program, NodaTime.TzdbCompiler", throwOnError: true)!;
            var main = program.GetMethod("Main", BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public)!;
            string[] compilerArgs = ["-s", tzdata, "-w", windowsZonesPath, "-o", nzdPath];
            Console.WriteLine($"  NodaTime.TzdbCompiler {string.Join(' ', compilerArgs)}");
            var exitCode = await (Task<int>) main.Invoke(null, [compilerArgs])!;
            if (exitCode != 0)
                throw new InvalidOperationException($"NodaTime.TzdbCompiler failed with exit code {exitCode}");
            return (await File.ReadAllBytesAsync(nzdPath),
                $"compiled by NodaTime.TzdbCompiler {ToolEnvironment.NodaTimeTag} from {tzdataOrigin} ({Path.GetFileName(tzdata)}) and {cldrOrigin}");
        }
        finally
        {
            Directory.Delete(work, recursive: true);
        }
    }

    /// <summary>
    /// TzdbCompiler infers the tz version from a Makefile or from a "tzdata2026a"-style file name, and
    /// IANA's data-only tarballs have neither when named "tzdata-latest". So: fetch the tarball, read
    /// its "version" file, and save it locally as tzdata&lt;version&gt;.tar.gz.
    /// </summary>
    private static async Task<string> LocalVersionedTarball(string tzdata, string work)
    {
        byte[] bytes;
        if (tzdata.StartsWith("http://", StringComparison.Ordinal) || tzdata.StartsWith("https://", StringComparison.Ordinal))
        {
            using var client = Downloads.CreateClient();
            bytes = await client.GetByteArrayAsync(tzdata);
        }
        else if (File.Exists(tzdata))
        {
            bytes = await File.ReadAllBytesAsync(tzdata);
        }
        else
        {
            return tzdata; // a directory: the compiler handles it
        }
        string? version = null;
        using (var gzip = new System.IO.Compression.GZipStream(new MemoryStream(bytes), System.IO.Compression.CompressionMode.Decompress))
        using (var tar = new System.Formats.Tar.TarReader(gzip))
        {
            while (tar.GetNextEntry() is { } entry)
            {
                if (entry.Name.TrimStart('.', '/') == "version" && entry.DataStream is not null)
                {
                    using var reader = new StreamReader(entry.DataStream);
                    version = (await reader.ReadToEndAsync()).Trim();
                    break;
                }
            }
        }
        if (version is null)
            throw new InvalidDataException($"{tzdata} has no 'version' file");
        var path = Path.Combine(work, $"tzdata{version}.tar.gz");
        await File.WriteAllBytesAsync(path, bytes);
        return path;
    }

    private static async Task<(byte[], string)> DownloadLatest()
    {
        using var client = Downloads.CreateClient();
        var url = (await client.GetStringAsync("https://nodatime.org/tzdb/latest.txt")).Trim();
        return (await client.GetByteArrayAsync(url), url);
    }

    private static (byte[], string) Embedded()
    {
        using var stream = typeof(TzdbDateTimeZoneSource).Assembly.GetManifestResourceStream("NodaTime.TimeZones.Tzdb.nzd")!;
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        return (memory.ToArray(), $"Tzdb.nzd embedded in NodaTime {ToolEnvironment.NodaTimeTag}");
    }
}
