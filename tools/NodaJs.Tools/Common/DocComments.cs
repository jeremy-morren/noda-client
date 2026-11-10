using System.Reflection;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace NodaJs.Tools.Common;

/// <summary>Part of a doc comment line, which each <see cref="CodeWriter"/> renders its way.</summary>
public abstract record DocPart;

public sealed record TextPart(string Text) : DocPart;

/// <summary><c>&lt;c&gt;</c> or a <c>langword</c>.</summary>
public sealed record CodePart(string Code) : DocPart;

/// <summary>A link to <paramref name="Target"/> ("Duration.FromDays").</summary>
public sealed record LinkPart(string Target) : DocPart;

/// <summary>A member exported from a calendar entry point instead (e.g. "HebrewCivil" from "hebrew"): named, not linked.</summary>
public sealed record MovedPart(string Member, string Module) : DocPart;

/// <summary>Doc comment lines (none blank), and the linked types (a TS file imports them).</summary>
public sealed record DocComment(IReadOnlyList<IReadOnlyList<DocPart>> Lines, IReadOnlySet<Type> LinkedTypes)
{
    public static readonly DocComment Empty = new([], new HashSet<Type>());

    public DocComment AppendLine(string text) => this with { Lines = [.. Lines, [new TextPart(text)]] };
}

/// <summary>An assembly's XML doc comments.</summary>
public sealed partial class DocComments
{
    private readonly Dictionary<string, XElement> _members = new(StringComparer.Ordinal);

    // By doc comment name, where '.' also separates nested types.
    private readonly Dictionary<string, Type> _types;

    public DocComments(Assembly assembly)
    {
        _types = assembly.GetTypes().ToDictionary(XmlName, StringComparer.Ordinal);
        var path = Path.ChangeExtension(assembly.Location, ".xml");
        if (!File.Exists(path))
            return;
        foreach (var member in XDocument.Load(path).Descendants("member"))
            _members[(string) member.Attribute("name")!] = member;
    }

    public DocComment? Summary(Type type) => Summary("T:" + XmlName(type));

    public DocComment? Summary(FieldInfo field) => Summary("F:" + XmlName(field.DeclaringType!) + "." + field.Name);

    /// <summary>"ZoneEqualityComparer+Options" → "ZoneEqualityComparerOptions" (the ports have no nested types).</summary>
    public static string FlatTypeName(Type type) =>
        (type.DeclaringType is null ? "" : FlatTypeName(type.DeclaringType)) +
        (type.Name.Contains('`') ? type.Name[..type.Name.IndexOf('`')] : type.Name);

    private DocComment? Summary(string id)
    {
        if (!_members.TryGetValue(id, out var member))
            return null;
        var links = new HashSet<Type>();
        var lines = new LineBuilder();
        if (member.Element("summary") is { } summary)
            AddParts(summary, lines, links);
        if (member.Element("remarks") is { } remarks)
        {
            lines.Break();
            AddParts(remarks, lines, links);
        }
        return new DocComment(lines.Lines(), links);
    }

    private static string XmlName(Type type) => type.FullName!.Replace('+', '.');

    private void AddParts(XElement element, LineBuilder lines, HashSet<Type> links)
    {
        foreach (var node in element.Nodes())
            switch (node)
            {
                case XText text:
                    lines.Text(WhitespaceRegex().Replace(text.Value, " "));
                    break;
                case XElement e when e.Name == "see" || e.Name == "seealso":
                    var cref = (string?) e.Attribute("cref");
                    var langword = (string?) e.Attribute("langword");
                    if (cref is not null && MovedMember(cref) is { } moved)
                        lines.Add(moved);
                    else if (cref is not null)
                        lines.Add(new LinkPart(CrefToTs(cref, links)));
                    else if (langword is not null)
                        lines.Add(new CodePart(langword));
                    break;
                case XElement e when e.Name == "c":
                    lines.Add(new CodePart(e.Value));
                    break;
                case XElement e when e.Name == "paramref" || e.Name == "typeparamref":
                    lines.Text((string?) e.Attribute("name") ?? "");
                    break;
                case XElement e when e.Name == "para":
                    lines.Break();
                    AddParts(e, lines, links);
                    lines.Break();
                    break;
                case XElement e:
                    AddParts(e, lines, links);
                    break;
            }
    }

    /// <summary>Doc parts by line: adjacent text joined, lines trimmed, blank lines left out.</summary>
    private sealed class LineBuilder
    {
        private readonly List<List<DocPart>> _lines = [[]];

        public void Text(string text)
        {
            var line = _lines[^1];
            if (line is [.., TextPart last])
                line[^1] = new TextPart(last.Text + text);
            else
                line.Add(new TextPart(text));
        }

        public void Add(DocPart part) => _lines[^1].Add(part);

        public void Break() => _lines.Add([]);

        public IReadOnlyList<IReadOnlyList<DocPart>> Lines() =>
            _lines.Select(Trim).Where(l => l.Count > 0).ToList();

        private static IReadOnlyList<DocPart> Trim(List<DocPart> line)
        {
            var parts = line.ToList();
            if (parts is [TextPart first, ..])
                parts[0] = new TextPart(first.Text.TrimStart());
            if (parts is [.., TextPart last])
                parts[^1] = new TextPart(last.Text.TrimEnd());
            return parts.Where(p => p is not TextPart { Text: "" }).ToList();
        }
    }

    /// <summary>"M:NodaTime.Duration.FromDays(System.Int32)" → "Duration.FromDays"; adds the type to <paramref name="links"/>.</summary>
    private string CrefToTs(string cref, HashSet<Type> links)
    {
        var name = cref[2..];
        var paren = name.IndexOf('(');
        if (paren >= 0)
            name = name[..paren];
        var parts = name.Split('.');
        for (var typeParts = parts.Length; typeParts > 0; typeParts--)
        {
            if (!_types.TryGetValue(string.Join('.', parts[..typeParts]), out var type))
                continue;
            links.Add(type);
            return string.Join('.', [FlatTypeName(type), .. parts[typeParts..]]);
        }
        // Not the assembly's (e.g. System.ArgumentException).
        return string.Join('.', parts.Where(p => p is not ("NodaTime" or "System")));
    }

    // Exported from noda-js/calendars/<name> instead (so bundles hold only imported calendars): named, not linked.
    private static readonly Dictionary<string, string> MovedMembers = new()
    {
        ["NodaTime.CalendarSystem.HebrewCivil"] = "hebrew",
        ["NodaTime.CalendarSystem.HebrewScriptural"] = "hebrew",
        ["NodaTime.CalendarSystem.GetHebrewCalendar"] = "hebrew",
        ["NodaTime.CalendarSystem.GetIslamicCalendar"] = "islamic",
        ["NodaTime.CalendarSystem.IslamicBcl"] = "islamic",
        ["NodaTime.CalendarSystem.PersianSimple"] = "persian",
        ["NodaTime.CalendarSystem.PersianArithmetic"] = "persian",
        ["NodaTime.CalendarSystem.PersianAstronomical"] = "persian",
        ["NodaTime.CalendarSystem.UmAlQura"] = "umalqura",
        ["NodaTime.CalendarSystem.Badi"] = "badi",
    };

    private static MovedPart? MovedMember(string cref)
    {
        var name = cref[2..];
        var paren = name.IndexOf('(');
        if (paren >= 0)
            name = name[..paren];
        return MovedMembers.TryGetValue(name, out var entry)
            ? new MovedPart(name[(name.LastIndexOf('.') + 1)..], entry)
            : null;
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespaceRegex();
}
