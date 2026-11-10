using System.CommandLine;
using NodaJs.Package;

// The release scripts' archives, independent of the machine's zip and tar.

var zip = ArchiveCommand("zip", "Writes a zip archive.", Archive.WriteZip);
var tarGzip = ArchiveCommand("tar-gzip", "Writes a gzip-compressed tar archive.", Archive.WriteTarGzip);

var archiveArgument = new Argument<FileInfo>("archive")
{
    Description = "The .tar.gz (or .tgz) archive to extract.",
};
var extractDirectoryOption = new Option<DirectoryInfo>("--directory")
{
    Description = "The directory to extract into (created if it doesn't exist).",
    Required = true,
};
var extractTarGzip = new Command("extract-tar-gzip", "Extracts a gzip-compressed tar archive.")
{
    archiveArgument, extractDirectoryOption,
};
extractTarGzip.SetAction(result =>
{
    var archive = result.GetValue(archiveArgument)!;
    var directory = result.GetValue(extractDirectoryOption)!;
    directory.Create();
    using (var stream = archive.OpenRead())
        Archive.ExtractTarGzip(stream, directory.FullName);
    Console.WriteLine($"Extracted {archive.FullName} into {directory.FullName}");
    return 0;
});

var root = new RootCommand("Reproducible zip and tar.gz release archives, and extraction.")
{
    zip, tarGzip, extractTarGzip,
};
return root.Parse(args).Invoke();

Command ArchiveCommand(string name, string description, Action<Stream, IReadOnlyList<ArchiveFile>, DateTimeOffset> write)
{
    var outputArgument = new Argument<FileInfo>("output")
    {
        Description = "The archive to write (replaced if it exists).",
    };
    var filesArgument = new Argument<string[]>("files")
    {
        Description = "The files to archive, in order, relative to --directory.",
        Arity = ArgumentArity.ZeroOrMore,
    };
    var filesFromOption = new Option<FileInfo?>("--files-from")
    {
        Description = "A UTF-8 file listing more files to archive, one per line.",
    };
    var timeOption = new Option<DateTimeOffset>("--time")
    {
        Description = "Every entry's modification time (ISO 8601).",
        Required = true,
    };
    var directoryOption = new Option<DirectoryInfo?>("--directory")
    {
        Description = "The directory the files are in (default: the working directory).",
    };

    var command = new Command(name, description) { outputArgument, filesArgument, filesFromOption, timeOption, directoryOption };
    command.SetAction(result =>
    {
        var directory = result.GetValue(directoryOption)?.FullName ?? Environment.CurrentDirectory;
        var filesFrom = result.GetValue(filesFromOption);
        IEnumerable<string> listed = filesFrom is null
            ? []
            : File.ReadAllLines(filesFrom.FullName).Where(line => line.Length > 0);
        var files = (result.GetValue(filesArgument) ?? []).Concat(listed)
            .Select(file => new ArchiveFile(file.Replace('\\', '/'), Path.Combine(directory, file)))
            .ToList();
        if (files.Count == 0)
            throw new ArgumentException("No files to archive: give them as arguments or with --files-from.");
        var output = result.GetValue(outputArgument)!;
        using (var stream = File.Create(output.FullName))
            write(stream, files, result.GetValue(timeOption));
        output.Refresh();
        Console.WriteLine($"Wrote {output.FullName} ({output.Length} bytes)");
        return 0;
    });
    return command;
}
