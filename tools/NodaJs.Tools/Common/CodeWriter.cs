using System.Diagnostics.CodeAnalysis;
using System.Text;
// ReSharper disable UnusedMethodReturnValue.Global
// ReSharper disable MemberCanBePrivate.Global

namespace NodaJs.Tools.Common;

/// <summary>Writes generated source: two-space indents, "\n" line endings; subclasses add each language's syntax.</summary>
public abstract class CodeWriter
{
    private readonly StringBuilder _sb = new();

    private int _indentLevel;

    /// <summary>Throws in a language switch's default case: a writer it has no case for.</summary>
    [DoesNotReturn]
    public void ThrowUnknown() => throw new NotSupportedException($"No case for {GetType().Name}.");

    /// <summary><see cref="ThrowUnknown()"/> in a switch expression.</summary>
    [DoesNotReturn]
    public T ThrowUnknown<T>() => throw new NotSupportedException($"No case for {GetType().Name}.");

    public CodeWriter PushIndent()
    {
        _indentLevel++;
        return this;
    }

    public CodeWriter PopIndent()
    {
        if (_indentLevel == 0)
            throw new InvalidOperationException("PopIndent without a matching PushIndent.");
        _indentLevel--;
        return this;
    }

    private string Indent => new(' ', _indentLevel * 2);

    public CodeWriter AppendIndent()
    {
        _sb.Append(Indent);
        return this;
    }

    public CodeWriter AppendOnLine(string text)
    {
        _sb.Append(text);
        return this;
    }

    public CodeWriter AppendNewline()
    {
        _sb.Append('\n');
        return this;
    }

    public CodeWriter WriteLine() => AppendNewline();

    public CodeWriter WriteLine(string line, bool emptyLineAfter = false)
    {
        AppendIndent();
        _sb.Append(line);
        if (emptyLineAfter)
            AppendNewline();
        return AppendNewline();
    }

    public CodeWriter WriteLines(IEnumerable<string> lines, bool emptyLineAfter = false)
    {
        foreach (var line in lines)
            WriteLine(line);
        if (emptyLineAfter)
            AppendNewline();
        return this;
    }

    public CodeWriter OpenBlock(string line) => WriteLine(line).PushIndent();

    public CodeWriter CloseBlock(string line, bool emptyLineAfter = false) => PopIndent().WriteLine(line, emptyLineAfter);

    /// <summary>Opens a value that starts mid-line: appends <paramref name="open"/>, ends the line, indents.</summary>
    public CodeWriter OpenInline(string open) => AppendOnLine(open).AppendNewline().PushIndent();

    /// <summary>Unindents and starts a line with <paramref name="close"/>, left for the caller to finish.</summary>
    public CodeWriter CloseInline(string close) => PopIndent().AppendIndent().AppendOnLine(close);

    /// <summary><c>name: value,</c>: an object property (TS) or named argument (Dart).</summary>
    public CodeWriter Property(string name, string value) => WriteLine($"{name}: {value},");

    /// <summary>A <see cref="Property"/> per property of an anonymous object, leaving out those whose value is null.</summary>
    public CodeWriter Properties(object parts)
    {
        foreach (var part in NamedValue<string>.FromObject(parts))
            Property(part.Name, part.Value);
        return this;
    }

    public CodeWriter Comment(string text)
    {
        // Raw string literals may have CRLF line endings.
        foreach (var line in text.Split('\n').Select(l => l.TrimEnd('\r')))
            WriteLine(line.Length == 0 ? "//" : "// " + line);
        return this;
    }

    /// <summary>A JSDoc or <c>///</c> comment of literal text: a line per <c>\n</c>, blank lines left out.</summary>
    public CodeWriter DocComment(string? text) =>
        WriteDocComment((text ?? "").Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).ToList());

    /// <summary>A JSDoc or <c>///</c> comment from NodaTime's docs; each language renders the parts its way.</summary>
    public CodeWriter DocComment(DocComment? doc) =>
        WriteDocComment(doc is null ? [] : doc.Lines.Select(l => string.Concat(l.Select(RenderDocPart))).ToList());

    /// <summary>Writes a doc comment's lines (nothing for none).</summary>
    protected abstract CodeWriter WriteDocComment(IReadOnlyList<string> lines);

    protected abstract string RenderDocPart(DocPart part);

    public abstract string Str(string? value);

    public string Bool(bool value) => value ? "true" : "false";

    /// <summary>An integer literal for generated test data.</summary>
    public abstract string Int(long value);

    /// <summary>An integer literal for generated library source.</summary>
    public abstract string SourceInt(long value);

    public abstract string Value(EncodedValue value);

    public string List(IEnumerable<string> items) => "[" + string.Join(", ", items) + "]";

    /// <summary>TS <c>[a, b]</c>, Dart <c>(a, b)</c>.</summary>
    public abstract string Tuple(IEnumerable<string> items);

    /// <summary>
    /// TS <c>{ a: 1 }</c>, Dart <c>Type(a: 1)</c> (a record for an empty <paramref name="type"/>), from an anonymous
    /// object's properties (<c>new { a = "1" }</c>), leaving out those whose value is null.
    /// </summary>
    public abstract string Object(string type, object parts);

    public abstract CodeWriter OpenObject(string type);

    public abstract CodeWriter CloseObject();

    /// <summary><c>name: {</c> or <c>name: Type(</c> (a list element without <paramref name="name"/>).</summary>
    public abstract CodeWriter OpenObjectLine(string type, string? name = null);

    public abstract CodeWriter CloseObjectLine();

    /// <summary>Imports <paramref name="typesModule"/> (relative, no extension) and opens a top-level constant.</summary>
    public abstract CodeWriter OpenConstObject(string name, string type, string typesModule, bool constant);

    public abstract CodeWriter CloseConstObject();

    public override string ToString() => _sb.ToString();
}
