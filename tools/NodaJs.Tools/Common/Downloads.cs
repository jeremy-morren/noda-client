using System.Diagnostics;

namespace NodaJs.Tools.Common;

public static class Downloads
{
    /// <summary>
    /// URL for the latest tzdata release from IANA.
    /// </summary>
    public const string IanaTzdataLatest = "https://data.iana.org/time-zones/tzdata-latest.tar.gz";

    private static readonly HttpClient Client = new();

    /// <summary>The bytes at a URL.</summary>
    public static byte[] GetBytes(string url)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        using var response = Client.Send(request, HttpCompletionOption.ResponseContentRead);
        response.EnsureSuccessStatusCode();
        var stream = response.Content.ReadAsStream();
        Trace.Assert(stream is MemoryStream, "ResponseContentRead should have buffered the response into a MemoryStream.");
        return ((MemoryStream)stream).ToArray();
    }
}
