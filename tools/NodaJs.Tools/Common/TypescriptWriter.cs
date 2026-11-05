using System.Text;
// ReSharper disable UnusedMethodReturnValue.Global
// ReSharper disable MemberCanBePrivate.Global

namespace NodaJs.Tools.Common;

/// <summary>
/// A simple writer for TypeScript files: lines at the current indentation (two spaces per level), with "\n" line
/// endings. <see cref="GeneratedFiles"/> writes the result as UTF-8 without a BOM.
/// </summary>
/// <remarks>
/// Most code writes whole lines (<see cref="WriteLine(string, bool)"/>, <see cref="Property"/>,
/// <see cref="OpenBlock"/>/<see cref="CloseBlock"/>). A value that starts in the middle of a line, such as an object
/// literal after <c>export const x = </c>, uses <see cref="OpenInline"/>/<see cref="CloseInline"/>, and the caller
/// finishes the line with <see cref="AppendOnLine"/> and <see cref="AppendNewline"/>.
/// </remarks>
public class TypescriptWriter
{
    private readonly StringBuilder _sb = new();

    private int _indentLevel;

    /// <summary>Indents the lines written after this by one more level.</summary>
    public TypescriptWriter PushIndent()
    {
        _indentLevel++;
        return this;
    }

    /// <summary>Undoes a <see cref="PushIndent"/>.</summary>
    public TypescriptWriter PopIndent()
    {
        if (_indentLevel == 0)
            throw new InvalidOperationException("PopIndent without a matching PushIndent.");
        _indentLevel--;
        return this;
    }

    private string Indent => new(' ', _indentLevel * 2);

    /// <summary>
    /// Writes the current indentation to the output.
    /// </summary>
    public TypescriptWriter AppendIndent()
    {
        _sb.Append(Indent);
        return this;
    }

    /// <summary>
    /// Appends text to the output without indentation or a newline.
    /// </summary>
    public TypescriptWriter AppendOnLine(string text)
    {
        _sb.Append(text);
        return this;
    }

    /// <summary>
    /// Writes a newline to the output.
    /// </summary>
    public TypescriptWriter AppendNewline()
    {
        _sb.Append('\n');
        return this;
    }

    /// <summary>Writes an empty line (without indentation).</summary>
    public TypescriptWriter WriteLine() => AppendNewline();

    /// <summary>
    /// Writes a line to the output, with indentation and a newline, and optionally an empty line after it.
    /// </summary>
    public TypescriptWriter WriteLine(string line, bool emptyLineAfter = false)
    {
        AppendIndent();
        _sb.Append(line);
        if (emptyLineAfter)
            AppendNewline();
        return AppendNewline();
    }

    /// <summary>
    /// Writes multiple lines to the output, with indentation and a newline after each line. Optionally adds an empty line after the last line.
    /// </summary>
    public TypescriptWriter WriteLines(IEnumerable<string> lines, bool emptyLineAfter = false)
    {
        foreach (var line in lines)
            WriteLine(line);
        if (emptyLineAfter)
            AppendNewline();
        return this;
    }

    /// <summary>Writes a line (e.g. <c>export const x = {</c>) and indents the lines after it.</summary>
    public TypescriptWriter OpenBlock(string line) => WriteLine(line).PushIndent();

    /// <summary>Unindents and writes the line that closes a block (e.g. <c>};</c>).</summary>
    public TypescriptWriter CloseBlock(string line, bool emptyLineAfter = false) => PopIndent().WriteLine(line, emptyLineAfter);

    /// <summary>
    /// Appends <paramref name="open"/> (e.g. <c>{</c>) to the current line, ends the line and indents the lines after
    /// it: for a value that starts in the middle of a line.
    /// </summary>
    public TypescriptWriter OpenInline(string open) => AppendOnLine(open).AppendNewline().PushIndent();

    /// <summary>
    /// Unindents and starts a line with <paramref name="close"/> (e.g. <c>}</c>) without ending it, so the caller can
    /// finish it (e.g. with <c>,</c> or <c>);</c>).
    /// </summary>
    public TypescriptWriter CloseInline(string close) => PopIndent().AppendIndent().AppendOnLine(close);

    /// <summary>Writes an object literal property line: <c>name: value,</c>.</summary>
    public TypescriptWriter Property(string name, string value) => WriteLine($"{name}: {value},");

    /// <summary>Writes each line of <paramref name="text"/> as a <c>//</c> comment.</summary>
    public TypescriptWriter Comment(string text)
    {
        // TrimEnd('\r'): a raw string literal has the source file's line endings, which may be CRLF.
        foreach (var line in text.Split('\n').Select(l => l.TrimEnd('\r')))
            WriteLine(line.Length == 0 ? "//" : "// " + line);
        return this;
    }

    /// <summary>
    /// Writes a JSDoc comment: nothing for empty text, <c>/** text */</c> for one line,
    /// otherwise one <c> * </c> line per (trimmed, non-empty) line of <paramref name="text"/>.
    /// </summary>
    public TypescriptWriter DocComment(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return this;
        var lines = text.Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).ToList();
        if (lines.Count == 1)
            return WriteLine($"/** {lines[0]} */");
        WriteLine("/**");
        foreach (var line in lines)
            WriteLine(" * " + line);
        return WriteLine(" */");
    }

    public override string ToString() => _sb.ToString();
}
