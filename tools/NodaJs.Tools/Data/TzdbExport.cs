using System.Formats.Tar;
using System.IO.Compression;
using System.Security.Cryptography;
using NodaJs.Tools.Common;
using NodaTime.TimeZones;

namespace NodaJs.Tools.Data;

/// <summary>An NZD file and where it came from.</summary>
internal sealed record TzdbSource(byte[] NzdData, string Origin);

/// <summary>
/// The bundled NZD, as base64: "compile" (NodaTime's TzdbCompiler on the latest IANA and CLDR releases,
/// so new tz data doesn't wait for nodatime.org), "latest" (nodatime.org's), or "embedded" (the pinned NodaTime's; offline).
/// </summary>
internal static class TzdbExport
{
    private const string TzdataFixtureDirectory = ToolEnvironment.TestData + "/tzdb";

    public static void Run(GeneratedFiles output, string source, string? tzdataSource, string? cldrSource)
    {
        var tzdbSource = source switch
        {
            "compile" => Compile(output, tzdataSource ?? Downloads.IanaTzdataLatest, cldrSource),
            "latest" => DownloadLatest(),
            "embedded" => Embedded(),
            _ => throw new ArgumentException($"Unknown tzdb source '{source}' (expected compile, latest or embedded)"),
        };
        var data = tzdbSource.NzdData;

        var tzdb = TzdbDateTimeZoneSource.FromStream(new MemoryStream(data));
        tzdb.Validate();
        var sha256 = Convert.ToHexStringLower(SHA256.HashData(data));

        var zoneCount = tzdb.CanonicalIdMap.Values.Distinct().Count();
        var base64 = Convert.ToBase64String(data);
        var latin1LiteralSize = System.Text.Encoding.UTF8.GetByteCount(Dart.Str(System.Text.Encoding.Latin1.GetString(data)));
        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            string Const(string name, string dartType, string value) => body switch
            {
                TypescriptWriter => $"export const {name} = {value};",
                DartWriter => $"const {dartType} {name} = {value};",
                _ => body.ThrowUnknown<string>(),
            };
            switch (body)
            {
                case TypescriptWriter:
                    break;
                case DartWriter:
                    body.WriteLine("import 'dart:convert';")
                        .WriteLine("import 'dart:typed_data';", emptyLineAfter: true);
                    break;
                default:
                    body.ThrowUnknown();
                    break;
            }
            body.DocComment("The tzdb release in the bundled data, e.g. \"2025b\".")
                .WriteLine(Const("tzdbVersion", "String", body.Str(tzdb.TzdbVersion)), emptyLineAfter: true)
                .DocComment("NodaTime's version ID for the bundled data.")
                .WriteLine(Const("versionId", "String", body.Str(tzdb.VersionId)), emptyLineAfter: true)
                .DocComment("SHA-256 of the NZD bytes.")
                .WriteLine(Const("sha256", "String", body.Str(sha256)), emptyLineAfter: true)
                .DocComment("Number of canonical zone IDs.")
                .WriteLine(Const("zoneCount", "int", zoneCount.ToString(System.Globalization.CultureInfo.InvariantCulture)), emptyLineAfter: true);
            switch (body)
            {
                case TypescriptWriter:
                    body.DocComment($"The NZD file ({data.Length} bytes), base64-encoded.")
                        .WriteLine(Const("nzdBase64", "String", body.Str(base64)));
                    break;
                case DartWriter:
                    body.DocComment($"The NZD file ({data.Length} bytes) as base64: {base64.Length} bytes of source, against {latin1LiteralSize} as a Latin-1 string literal.")
                        .WriteLine(Const("nzdBase64", "String", body.Str(base64)), emptyLineAfter: true)
                        .DocComment("The NZD file, decoded on first use.")
                        .WriteLine("final Uint8List nzdBytes = base64Decode(nzdBase64);");
                    break;
                default:
                    body.ThrowUnknown();
                    break;
            }
            output.Write(port.Source("TimeZones/TzdbBundledData"), "tzdb", body,
                [$"Source: {tzdbSource.Origin}", "tz data is public domain; the CLDR Windows mapping in it is under the Unicode License (see NOTICE.txt)."]);
        }
    }

    private static TzdbSource Compile(GeneratedFiles output, string tzdata, string? cldrSource)
    {
        var cldr = Cldr.CldrWindowsZonesFile.Load(cldrSource);
        var work = Path.Combine(Path.GetTempPath(), "noda-js-tzdb-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        try
        {
            var windowsZonesPath = Path.Combine(work, "windowsZones.xml");
            var nzdPath = Path.Combine(work, "tzdb.nzd");
            cldr.Document.Save(windowsZonesPath);
            var tzdataOrigin = tzdata;
            tzdata = LocalVersionedTarball(output, tzdata, work);

            string[] compilerArgs = ["-s", tzdata, "-w", windowsZonesPath, "-o", nzdPath];
            Console.WriteLine($"  NodaTime.TzdbCompiler {string.Join(' ', compilerArgs)}");
            var exitCode = NodaTimeInternals.TzdbCompilerMain(null, compilerArgs).GetAwaiter().GetResult();
            if (exitCode != 0)
                throw new InvalidOperationException($"NodaTime.TzdbCompiler failed with exit code {exitCode}");
            return new TzdbSource(
                File.ReadAllBytes(nzdPath),
                $"compiled by NodaTime.TzdbCompiler {ToolEnvironment.NodaTimeVersion} from {tzdataOrigin} ({Path.GetFileName(tzdata)}) and {cldr.Origin}");
        }
        finally
        {
            Directory.Delete(work, recursive: true);
        }
    }

    /// <summary>
    /// Saves the tarball as tzdata&lt;version&gt;.tar, from its "version" file:
    /// TzdbCompiler takes the version from the file name.
    /// Also keeps it as a test fixture.
    /// </summary>
    private static string LocalVersionedTarball(GeneratedFiles output, string tzdata, string work)
    {
        byte[] bytes;
        if (tzdata.StartsWith("http://", StringComparison.Ordinal) || tzdata.StartsWith("https://", StringComparison.Ordinal))
            bytes = Downloads.GetBytes(tzdata);
        else if (File.Exists(tzdata))
            bytes = File.ReadAllBytes(tzdata);
        else
            return tzdata; // a directory

        using var tarBytes = new MemoryStream(bytes);
        var tarStream = Decompress(tarBytes);
        string? version = null;
        tarBytes.Position = 0;
        using (var tar = new TarReader(tarStream, leaveOpen: true))
        {
            while (tar.GetNextEntry() is { } entry)
            {
                if (entry.Name.TrimStart('.', '/') == "version" && entry.DataStream is not null)
                {
                    using var reader = new StreamReader(entry.DataStream);
                    version = reader.ReadToEnd().Trim();
                    break;
                }
            }
        }
        if (version is null)
            throw new InvalidDataException($"{tzdata} has no 'version' file");
        output.WriteBinary($"{TzdataFixtureDirectory}/tzdata{version}.tar.gz", bytes);
        output.DeleteStale(TzdataFixtureDirectory, "tzdata*.tar.gz");
        var path = Path.Combine(work, $"tzdata{version}.tar");
        File.WriteAllBytes(path, tarBytes.ToArray());
        return path;
    }

    private static TzdbSource DownloadLatest()
    {
        var url = System.Text.Encoding.UTF8.GetString(Downloads.GetBytes("https://nodatime.org/tzdb/latest.txt")).Trim();
        return new TzdbSource(Downloads.GetBytes(url), url);
    }

    private static TzdbSource Embedded()
    {
        using var stream = typeof(TzdbDateTimeZoneSource).Assembly.GetManifestResourceStream("NodaTime.TimeZones.Tzdb.nzd")!;
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        return new TzdbSource(memory.ToArray(), $"Tzdb.nzd embedded in NodaTime {ToolEnvironment.NodaTimeVersion}");
    }

    private static Stream Decompress(MemoryStream stream)
    {
        if (stream.Length < 2)
            return stream; // Too short to be compressed.
        var first = stream.ReadByte();
        var second = stream.ReadByte();
        stream.Position = 0;
        if (first == 0x1F && second == 0x8B)
            // Stream is a gzip stream
            return new GZipStream(stream, CompressionMode.Decompress);
        return stream;
    }
}
