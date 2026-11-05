using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace NodaJs.Tools.Common;

/// <summary>
/// A doc comment converted to JSDoc text, and the types its <c>{@link}</c>s refer to (which the generated file must
/// import for the links to resolve).
/// </summary>
public sealed record DocComment(string Text, IReadOnlySet<Type> LinkedTypes);

/// <summary>
/// Reads the XML documentation file built alongside an assembly, so generated code can keep
/// NodaTime's doc comments.
/// </summary>
public sealed partial class DocComments
{
    private readonly Dictionary<string, XElement> _members = new(StringComparer.Ordinal);

    // The assembly's types by their doc comment name ("NodaTime.TimeZones.ZoneEqualityComparer.Options"), to resolve
    // crefs, where '.' separates both namespaces and nested types.
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

    /// <summary>The TS name of a (possibly nested) type: "ZoneEqualityComparer+Options" → "ZoneEqualityComparerOptions".</summary>
    public static string TsTypeName(Type type) =>
        (type.DeclaringType is null ? "" : TsTypeName(type.DeclaringType)) +
        (type.Name.Contains('`') ? type.Name[..type.Name.IndexOf('`')] : type.Name);

    private DocComment? Summary(string id)
    {
        if (!_members.TryGetValue(id, out var member))
            return null;
        var links = new HashSet<Type>();
        var summary = member.Element("summary");
        var remarks = member.Element("remarks");
        var text = new StringBuilder(summary is null ? "" : ToText(summary, links));
        if (remarks is not null)
            text.Append('\n').Append(ToText(remarks, links));
        return new DocComment(text.ToString().Trim(), links);
    }

    private static string XmlName(Type type) => type.FullName!.Replace('+', '.');

    private string ToText(XElement element, HashSet<Type> links)
    {
        var builder = new StringBuilder();
        foreach (var node in element.Nodes())
            switch (node)
            {
                case XText text:
                    builder.Append(WhitespaceRegex().Replace(text.Value, " "));
                    break;
                case XElement e when e.Name == "see" || e.Name == "seealso":
                    var cref = (string?) e.Attribute("cref");
                    var langword = (string?) e.Attribute("langword");
                    if (cref is not null && MovedMember(cref) is { } moved)
                        builder.Append(moved);
                    else if (cref is not null)
                        builder.Append("{@link ").Append(CrefToTs(cref, links)).Append('}');
                    else if (langword is not null)
                        builder.Append('`').Append(langword).Append('`');
                    break;
                case XElement e when e.Name == "c":
                    builder.Append('`').Append(e.Value).Append('`');
                    break;
                case XElement e when e.Name == "paramref" || e.Name == "typeparamref":
                    builder.Append((string?) e.Attribute("name"));
                    break;
                case XElement e when e.Name == "para":
                    builder.Append('\n').Append(ToText(e, links)).Append('\n');
                    break;
                case XElement e:
                    builder.Append(ToText(e, links));
                    break;
            }
        return builder.ToString();
    }

    /// <summary>
    /// "M:NodaTime.Duration.FromDays(System.Int32)" → "Duration.FromDays";
    /// "F:NodaTime.TimeZones.ZoneEqualityComparer.Options.MatchAllTransitions" → "ZoneEqualityComparerOptions.MatchAllTransitions".
    /// The type part is the longest prefix naming a type in the assembly, written with its TS name (no namespace,
    /// nested types concatenated), and is added to <paramref name="links"/>.
    /// </summary>
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
            return string.Join('.', [TsTypeName(type), .. parts[typeParts..]]);
        }
        // Not one of the assembly's types (e.g. System.ArgumentException): drop the root namespaces.
        return string.Join('.', parts.Where(p => p is not ("NodaTime" or "System")));
    }

    // CalendarSystem members that noda-js exports from the calendar entry points instead (noda-js/calendars/<name>), so
    // that bundles only contain the calendars an app imports: the docs name them in code rather than linking to them.
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

    /// <summary>For a cref to a <see cref="MovedMembers">moved member</see>: <c>`Member` (noda-js/calendars/name)</c>.</summary>
    private static string? MovedMember(string cref)
    {
        var name = cref[2..];
        var paren = name.IndexOf('(');
        if (paren >= 0)
            name = name[..paren];
        return MovedMembers.TryGetValue(name, out var entry)
            ? $"`{name[(name.LastIndexOf('.') + 1)..]}` (noda-js/calendars/{entry})"
            : null;
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespaceRegex();
}
