using System.Globalization;
using System.Text;

namespace NodaJs.Tools.Common;

/// <summary>
/// Helpers for writing TypeScript source text.
/// </summary>
public static class Ts
{
    /// <summary>A double-quoted TS string literal.</summary>
    public static string Str(string? value)
    {
        if (value is null)
            return "null";
        var builder = new StringBuilder(value.Length + 2);
        builder.Append('"');
        foreach (var c in value)
            switch (c)
            {
                case '"': builder.Append(@"\"""); break;
                case '\\': builder.Append(@"\\"); break;
                case '\n': builder.Append(@"\n"); break;
                case '\r': builder.Append(@"\r"); break;
                case '\t': builder.Append(@"\t"); break;
                default:
                    // Escape controls, surrogates, format characters (e.g. RLM), non-ASCII spaces (e.g. NBSP,
                    // narrow NBSP) and line/paragraph separators, so the source is unambiguous.
                    var category = char.GetUnicodeCategory(c);
                    if (c < 0x20 || 
                        c == 0x7f || 
                        char.IsSurrogate(c) ||
                        category is UnicodeCategory.Format or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator ||
                        (category == UnicodeCategory.SpaceSeparator && c != ' ') ||
                        category is UnicodeCategory.OtherNotAssigned or UnicodeCategory.PrivateUse)
                        builder.Append(@"\u").Append(((int) c).ToString("x4", CultureInfo.InvariantCulture));
                    else
                        builder.Append(c);
                    break;
            }
        builder.Append('"');
        return builder.ToString();
    }

    public static string Bool(bool value) => value ? "true" : "false";

    /// <summary>
    /// An integer literal for generated <em>source</em> (src/), which has no bigint (noda-js targets ES2015): a number
    /// literal when the value is exactly representable as a double, otherwise a decimal string literal (the exact form
    /// that noda-js APIs taking a C# long accept).
    /// </summary>
    public static string SourceInt(long value) =>
        value == long.MinValue || (Math.Abs((double) value) < 9223372036854775808d && (long) (double) value == value)
            ? value.ToString(CultureInfo.InvariantCulture)
            : Str(value.ToString(CultureInfo.InvariantCulture));

    /// <inheritdoc cref="SourceInt(long)"/>
    public static string SourceInt(ulong value) =>
        value <= long.MaxValue ? SourceInt((long) value) : Str(value.ToString(CultureInfo.InvariantCulture));

    /// <summary>
    /// An integer literal for generated <em>test</em> data (test/, which runs on Node): a number if it's a safe integer,
    /// otherwise a bigint literal. Never use this for src/; see <see cref="SourceInt(long)"/>.
    /// </summary>
    public static string Int(long value) =>
        Math.Abs((double) value) <= 9007199254740991d && value != long.MinValue
            ? value.ToString(CultureInfo.InvariantCulture)
            : value.ToString(CultureInfo.InvariantCulture) + "n";

    public static string Int(ulong value) =>
        value <= 9007199254740991UL ? value.ToString(CultureInfo.InvariantCulture) : value.ToString(CultureInfo.InvariantCulture) + "n";

    /// <summary>A bigint literal, for generated test data only (see <see cref="Int(long)"/>).</summary>
    public static string BigInt(System.Numerics.BigInteger value) => value.ToString(CultureInfo.InvariantCulture) + "n";

    /// <summary>A number literal that round-trips the double exactly.</summary>
    public static string Double(double value)
    {
        if (double.IsNaN(value)) return "NaN";
        if (double.IsPositiveInfinity(value)) return "Infinity";
        if (double.IsNegativeInfinity(value)) return "-Infinity";
        if (value == 0 && double.IsNegative(value)) return "-0";
        return value.ToString("R", CultureInfo.InvariantCulture).Replace("E+", "e").Replace("E-", "e-");
    }

    /// <summary>
    /// Converts a C# member name to the noda-js camelCase name: the leading run of capitals is
    /// lower-cased as a block, except the last capital when it starts the next word
    /// ("AMDesignator" → "amDesignator", "ToUnixTimeTicks" → "toUnixTimeTicks", "ISO" → "iso").
    /// </summary>
    public static string CamelCase(string name)
    {
        if (string.IsNullOrEmpty(name) || !char.IsUpper(name[0]))
            return name;
        var upperRun = 0;
        while (upperRun < name.Length && char.IsUpper(name[upperRun]))
            upperRun++;
        if (upperRun == 1 || upperRun == name.Length)
            return name[..upperRun].ToLowerInvariant() + name[upperRun..];
        // "AMDesignator": run "AMD"; keep the "D" which begins "Designator" unless the next char isn't lower-case.
        var lowerCount = char.IsLower(name[upperRun]) ? upperRun - 1 : upperRun;
        return name[..lowerCount].ToLowerInvariant() + name[lowerCount..];
    }

    /// <summary>A valid TS identifier for a culture name ("fr-FR" → "frFR", "" → "invariant").</summary>
    public static string CultureIdentifier(string cultureName)
    {
        if (cultureName == "")
            return "invariant";
        var builder = new StringBuilder();
        foreach (var part in cultureName.Split('-', '_'))
            builder.Append(builder.Length == 0 ? part.ToLowerInvariant() : part);
        return builder.ToString();
    }
}
