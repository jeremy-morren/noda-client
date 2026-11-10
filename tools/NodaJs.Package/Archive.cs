using System.Formats.Tar;
using System.IO.Compression;

namespace NodaJs.Package;

public sealed record ArchiveFile(string Name, string Path);

/// <summary>Reproducible archives: the bytes depend only on the files, the time and .NET's zlib (pinned).</summary>
public static class Archive
{
    private const UnixFileMode FileMode =
        UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead | UnixFileMode.OtherRead;

    public static void WriteZip(Stream output, IReadOnlyList<ArchiveFile> files, DateTimeOffset time)
    {
        using var zip = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: true);
        foreach (var file in files)
        {
            var entry = zip.CreateEntry(file.Name, CompressionLevel.SmallestSize);
            // Zip stores a zoneless local time.
            entry.LastWriteTime = time.ToUniversalTime();
            // Unix attributes: a regular file, rw-r--r--.
            entry.ExternalAttributes = (0x8000 | (int)FileMode) << 16;
            using var source = File.OpenRead(file.Path);
            using var target = entry.Open();
            source.CopyTo(target);
        }
    }

    // Ustar: no access or change times.
    public static void WriteTarGzip(Stream output, IReadOnlyList<ArchiveFile> files, DateTimeOffset time)
    {
        using var tar = new MemoryStream();
        using (var writer = new TarWriter(tar, TarEntryFormat.Ustar, leaveOpen: true))
        {
            foreach (var file in files)
            {
                using var source = File.OpenRead(file.Path);
                writer.WriteEntry(new UstarTarEntry(TarEntryType.RegularFile, file.Name)
                {
                    ModificationTime = time,
                    Mode = FileMode,
                    DataStream = source,
                });
            }
        }

        using var compressed = new MemoryStream();
        using (var gzip = new GZipStream(compressed, CompressionLevel.SmallestSize, leaveOpen: true))
        {
            tar.Position = 0;
            tar.CopyTo(gzip);
        }
        // The gzip header's OS byte is zlib's build OS: set it to Unix (3).
        var bytes = compressed.GetBuffer().AsSpan(0, (int)compressed.Length);
        bytes[9] = 3;
        output.Write(bytes);
    }

    /// <summary>Extracts into an existing directory.</summary>
    public static void ExtractTarGzip(Stream input, string directory)
    {
        using var gzip = new GZipStream(input, CompressionMode.Decompress, leaveOpen: true);
        TarFile.ExtractToDirectory(gzip, directory, overwriteFiles: false);
    }
}
