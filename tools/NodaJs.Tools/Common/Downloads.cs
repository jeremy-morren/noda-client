using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Xml;
using System.Xml.Linq;

namespace NodaJs.Tools.Common;

/// <summary>
/// Upstream data sources the tools download.
/// </summary>
public static class Downloads
{
    /// <summary>The latest IANA tz database release (data only), as NodaTime's TzdbCompiler accepts it.</summary>
    public const string IanaTzdataLatest = "https://data.iana.org/time-zones/tzdata-latest.tar.gz";

    public static HttpClient CreateClient()
    {
        var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.ParseAdd("noda-js-tools");
        return client;
    }

    /// <summary>
    /// Downloads and parses CLDR's windowsZones.xml. <paramref name="source"/> is a local file, a CLDR release tag
    /// (e.g. "release-48"), or null for the latest CLDR release. Returns the document and where it came from.
    /// </summary>
    public static async Task<(XDocument Document, string Origin)> CldrWindowsZones(string? source)
    {
        if (source is not null && File.Exists(source))
            return (ParseXml(await File.ReadAllTextAsync(source)), Path.GetFullPath(source));
        using var client = CreateClient();
        var tag = source ?? await GetLatestCldrReleaseTag(client);
        var url = $"https://raw.githubusercontent.com/unicode-org/cldr/{tag}/common/supplemental/windowsZones.xml";
        var document = ParseXml(await client.GetStringAsync(url));
        // Recent CLDR files have an empty "$Revision$"; nodatime.org's NZD files report the mapping version
        // as the CLDR release number (e.g. "49" for release-49), so fill that in the same way. NodaTime's
        // CldrWindowsZonesParser reads the version from <supplementalData><version number="..."/>.
        var number = document.Root?.Element("version")?.Attribute("number");
        if (number is { Value: "$Revision$" } && ReleaseNumber(tag) is { } release)
            number.Value = $"$Revision: {release} $";
        return (document, url);
    }

    /// <summary>
    /// Parses XML without DTD processing (CLDR files name a DTD by a relative path that doesn't exist here).
    /// </summary>
    private static XDocument ParseXml(string xml)
    {
        var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Ignore };
        using var reader = XmlReader.Create(new StringReader(xml), settings);
        return XDocument.Load(reader);
    }

    /// <summary>The release number in a CLDR release tag: "release-49" → "49", "release-48-1" → "48.1"; else null.</summary>
    private static string? ReleaseNumber(string tag)
    {
        const string prefix = "release-";
        if (!tag.StartsWith(prefix, StringComparison.Ordinal))
            return null;
        var parts = tag[prefix.Length..].Split('-');
        return parts.All(p => p.Length > 0 && p.All(char.IsAsciiDigit)) ? string.Join('.', parts) : null;
    }

    private static async Task<string> GetLatestCldrReleaseTag(HttpClient client)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Get, 
            "https://api.github.com/repos/unicode-org/cldr/releases/latest");
        request.Headers.Accept.ParseAdd("application/vnd.github+json");
        using var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var release = await response.Content.ReadFromJsonAsync<GithubRelease>()!;
        return release!.TagName;
    }

    private record GithubRelease
    {
        [JsonPropertyName("tag_name")]
        public required string TagName { get; init; }
    }
}
