using System.Formats.Tar;
using System.IO.Compression;

namespace NodaJs.Package;

/// <summary>A file to archive: its entry name in the archive, and where it is on disk.</summary>
public sealed record ArchiveFile(string Name, string Path);

/// <summary>
/// Reproducible archives, so the release workflow can rebuild the release's assets byte for byte: entries in the given
/// order, each dated the given time, with mode 644 and no owner, at maximum compression, and nothing from the machine
/// (its time zone, user, or OS). The bytes depend only on the files, the time and .NET's zlib, which tools/global.json
/// pins.
/// </summary>
public static class Archive
{
    private const UnixFileMode FileMode =
        UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead | UnixFileMode.OtherRead;

    /// <summary>A zip archive.</summary>
    public static void WriteZip(Stream output, IReadOnlyList<ArchiveFile> files, DateTimeOffset time)
    {
        using var zip = new ZipArchive(output, ZipArchiveMode.Create, leaveOpen: true);
        foreach (var file in files)
        {
            var entry = zip.CreateEntry(file.Name, CompressionLevel.SmallestSize);
            // Zip stores a local time with no zone: UTC's, so the archive doesn't depend on the machine's zone.
            entry.LastWriteTime = time.ToUniversalTime();
            // Unix attributes, in the high 16 bits: a regular file (0o100000), rw-r--r--.
            entry.ExternalAttributes = (0x8000 | (int)FileMode) << 16;
            using var source = File.OpenRead(file.Path);
            using var target = entry.Open();
            source.CopyTo(target);
        }
    }

    /// <summary>A gzip-compressed tar archive (ustar format, so no access or change times).</summary>
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
        // The gzip header records no name or time; its OS byte is the OS zlib was built for, so set it to Unix (3).
        var bytes = compressed.GetBuffer().AsSpan(0, (int)compressed.Length);
        bytes[9] = 3;
        output.Write(bytes);
    }

    /// <summary>Extracts a gzip-compressed tar archive (e.g. an npm tarball) into a directory, which must exist.</summary>
    public static void ExtractTarGzip(Stream input, string directory)
    {
        using var gzip = new GZipStream(input, CompressionMode.Decompress, leaveOpen: true);
        TarFile.ExtractToDirectory(gzip, directory, overwriteFiles: false);
    }
}
