namespace NodaJs.Tools.Common;

/// <summary>
/// A code writer for Dart syntax.
/// </summary>
public sealed class DartWriter : CodeWriter
{
    // An empty /// line between lines: Markdown would join them.
    protected override CodeWriter WriteDocComment(IReadOnlyList<string> lines)
    {
        for (var i = 0; i < lines.Count; i++)
        {
            if (i > 0)
                WriteLine("///");
            WriteLine("/// " + lines[i]);
        }
        return this;
    }

    protected override string RenderDocPart(DocPart part) => part switch
    {
        TextPart text => text.Text,
        CodePart code => $"`{code.Code}`",
        LinkPart link => $"[{link.Target}]",
        MovedPart moved => $"`{moved.Member}` (package:noda_dart/calendars.dart)",
        _ => throw new ArgumentException($"Unknown doc part {part}"),
    };

    public override string Str(string? value) => Dart.Str(value);

    public override string Int(long value) => Dart.Int(value);

    public override string SourceInt(long value) => Dart.Int(value);

    public override string Value(EncodedValue value) => DartValueEncoder.Render(value);

    public override string Tuple(IEnumerable<string> items) => "(" + string.Join(", ", items) + ")";

    public override string Object(string type, object parts) =>
        type + "(" + string.Join(", ", NamedValue<string>.FromObject(parts).Select(p => $"{p.Name}: {p.Value}")) + ")";

    public override CodeWriter OpenObject(string type) => OpenInline(type + "(");

    public override CodeWriter CloseObject() => CloseInline(")");

    public override CodeWriter OpenObjectLine(string type, string? name = null) => OpenBlock(name is null ? type + "(" : $"{name}: {type}(");

    public override CodeWriter CloseObjectLine() => CloseBlock("),");

    public override CodeWriter OpenConstObject(string name, string type, string typesModule, bool constant) =>
        WriteLine($"import {Dart.Str(typesModule + ".dart")};", emptyLineAfter: true)
            .OpenBlock($"{(constant ? "const" : "final")} {name} = {type}(");

    public override CodeWriter CloseConstObject() => CloseBlock(");");
}
