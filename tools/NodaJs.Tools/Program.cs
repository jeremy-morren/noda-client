using System.CommandLine;
using NodaJs.Tools.Cldr;
using NodaJs.Tools.Common;
using NodaJs.Tools.Data;
using NodaJs.Tools.Scenarios;
using NodaJs.Tools.SystemZones;

var repoOption = new Option<string?>("--repo")
{
    Description = "The repository root (default: found from the working directory).",
    Recursive = true,
};
var tzdbOption = new Option<string>("--tzdb")
{
    Description = "The bundled tzdb: compiled by NodaTime's TzdbCompiler, nodatime.org's latest, or NodaTime's embedded one.",
    DefaultValueFactory = _ => "compile",
};
tzdbOption.AcceptOnlyFromAmong("compile", "latest", "embedded");
var tzdataOption = new Option<string?>("--tzdata")
{
    Description = "IANA tzdata tarball (URL or path) for --tzdb compile (default: the latest).",
};
var cldrOption = new Option<string?>("--cldr")
{
    Description = "A windowsZones.xml file (default: the one NodaTime picks from its data/cldr).",
};
var partsArgument = new Argument<string[]>("parts")
{
    Description = $"The parts to export (default: all): {string.Join(", ", DataCommand.Parts)}.",
    Arity = ArgumentArity.ZeroOrMore,
};
partsArgument.AcceptOnlyFromAmong(DataCommand.Parts);

var data = new Command("data", "Enums, constants, error messages, cultures, tzdb, API listing and golden vectors.")
{
    partsArgument, tzdbOption, tzdataOption, cldrOption,
};
data.SetAction(result => Run(result, output =>
    DataCommand.Run(output, result.GetValue(partsArgument)!, result.GetValue(tzdbOption)!, result.GetValue(tzdataOption), result.GetValue(cldrOption))));

var cldr = new Command("cldr", "CLDR's Windows ↔ tzdb zone ID mapping.") { cldrOption };
cldr.SetAction(result => Run(result, output => CldrExport.Run(output, result.GetValue(cldrOption))));

var scenarios = new Command("scenarios", "Every NUnit test case in NodaTime.Test and NodaTime.TzdbCompiler.Test.");
scenarios.SetAction(result => Run(result, output => new Extractor(output).Run()));

var all = new Command("all", "data, cldr and scenarios.") { tzdbOption, tzdataOption, cldrOption };
all.SetAction(result => Run(result, output =>
{
    DataCommand.Run(output, [], result.GetValue(tzdbOption)!, result.GetValue(tzdataOption), result.GetValue(cldrOption));
    CldrExport.Run(output, result.GetValue(cldrOption));
    new Extractor(output).Run();
}));

var outputOption = new Option<string>("--output")
{
    Description = $"Where to write the JSON (default: {ToolEnvironment.TestData}/system-zones.json in the repo).",
};
var systemZones = new Command("system-zones",
    "NodaTime's BclDateTimeZoneSource on this machine as JSON, for both ports' test/system/.")
{
    outputOption,
};
systemZones.SetAction(result =>
{
    if (result.GetValue(repoOption) is { } repo)
        ToolEnvironment.UseRepoRoot(repo);
    SystemZonesExport.Run(result.GetValue(outputOption) ?? Path.Combine(ToolEnvironment.RepoRoot, ToolEnvironment.TestData, "system-zones.json"));
    return 0;
});

var root = new RootCommand("Generates noda-js's *.generated.ts and noda_dart's *.generated.dart files from .NET and NodaTime.") { repoOption, data, cldr, scenarios, all, systemZones };
return root.Parse(args).Invoke();

int Run(ParseResult result, Action<GeneratedFiles> export)
{
    if (result.GetValue(repoOption) is { } repo)
        ToolEnvironment.UseRepoRoot(repo);
    ToolEnvironment.RequireIcu();
    Console.WriteLine($"NodaJs.Tools {result.CommandResult.Command.Name}: {ToolEnvironment.Describe()}; repo {ToolEnvironment.RepoRoot}");
    var output = new GeneratedFiles("NodaJs.Tools");
    export(output);
    output.Summarize();
    return 0;
}
