namespace NodaJs.Tools.Common;

/// <summary>
/// A code writer for TypeScript syntax.
/// </summary>
public sealed class TypescriptWriter : CodeWriter
{
    protected override CodeWriter WriteDocComment(IReadOnlyList<string> lines)
    {
        if (lines.Count == 0)
            return this;
        if (lines.Count == 1)
            return WriteLine($"/** {lines[0]} */");
        WriteLine("/**");
        foreach (var line in lines)
            WriteLine(" * " + line);
        return WriteLine(" */");
    }

    protected override string RenderDocPart(DocPart part) => part switch
    {
        TextPart text => text.Text,
        CodePart code => $"`{code.Code}`",
        LinkPart link => $"{{@link {link.Target}}}",
        MovedPart moved => $"`{moved.Member}` (noda-js/calendars/{moved.Module})",
        _ => throw new ArgumentException($"Unknown doc part {part}"),
    };

    public override string Str(string? value) => Ts.Str(value);

    public override string Int(long value) => Ts.Int(value);

    public override string SourceInt(long value) => Ts.SourceInt(value);

    public override string Value(EncodedValue value) => TsValueEncoder.Render(value);

    public override string Tuple(IEnumerable<string> items) => List(items);

    public override string Object(string type, object parts) =>
        "{ " + string.Join(", ", NamedValue<string>.FromObject(parts).Select(p => $"{p.Name}: {p.Value}")) + " }";

    public override CodeWriter OpenObject(string type) => OpenInline("{");

    public override CodeWriter CloseObject() => CloseInline("}");

    public override CodeWriter OpenObjectLine(string type, string? name = null) => OpenBlock(name is null ? "{" : $"{name}: {{");

    public override CodeWriter CloseObjectLine() => CloseBlock("},");

    public override CodeWriter OpenConstObject(string name, string type, string typesModule, bool constant) =>
        WriteLine($"import type {{ {type} }} from {Ts.Str(typesModule + ".ts")};", emptyLineAfter: true)
            .OpenBlock($"export const {name}: {type} = {{");

    public override CodeWriter CloseConstObject() => CloseBlock("};");
}
