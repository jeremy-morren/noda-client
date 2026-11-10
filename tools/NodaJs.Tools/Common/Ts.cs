using System.Globalization;
using System.Text;

namespace NodaJs.Tools.Common;

/// <summary>TypeScript source literals.</summary>
public static class Ts
{
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
                    // Invisible or ambiguous characters (controls, RLM, NBSP, separators...).
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

    /// <summary>For src/ (ES2015, no bigint): a number if exact as a double, else a decimal string.</summary>
    public static string SourceInt(long value) =>
        value == long.MinValue || (Math.Abs((double) value) < 9223372036854775808d && (long) (double) value == value)
            ? value.ToString(CultureInfo.InvariantCulture)
            : Str(value.ToString(CultureInfo.InvariantCulture));

    /// <inheritdoc cref="SourceInt(long)"/>
    public static string SourceInt(ulong value) =>
        value <= long.MaxValue ? SourceInt((long) value) : Str(value.ToString(CultureInfo.InvariantCulture));

    /// <summary>For test/ only: a number if safe, else a bigint.</summary>
    public static string Int(long value) => Int((System.Numerics.BigInteger) value);

    /// <inheritdoc cref="Int(long)"/>
    public static string Int(System.Numerics.BigInteger value) =>
        value.ToString(CultureInfo.InvariantCulture) + (System.Numerics.BigInteger.Abs(value) <= Dart.MaxSafeInteger ? "" : "n");

    /// <summary>For test/ only.</summary>
    public static string BigInt(System.Numerics.BigInteger value) => value.ToString(CultureInfo.InvariantCulture) + "n";

    public static string Double(double value)
    {
        if (double.IsNaN(value)) return "NaN";
        if (double.IsPositiveInfinity(value)) return "Infinity";
        if (double.IsNegativeInfinity(value)) return "-Infinity";
        if (value == 0 && double.IsNegative(value)) return "-0";
        return value.ToString("R", CultureInfo.InvariantCulture).Replace("E+", "e").Replace("E-", "e-");
    }

    /// <summary>"AMDesignator" → "amDesignator", "ToUnixTimeTicks" → "toUnixTimeTicks", "ISO" → "iso".</summary>
    public static string CamelCase(string name)
    {
        if (string.IsNullOrEmpty(name) || !char.IsUpper(name[0]))
            return name;
        var upperRun = 0;
        while (upperRun < name.Length && char.IsUpper(name[upperRun]))
            upperRun++;
        if (upperRun == 1 || upperRun == name.Length)
            return name[..upperRun].ToLowerInvariant() + name[upperRun..];
        var lowerCount = char.IsLower(name[upperRun]) ? upperRun - 1 : upperRun;
        return name[..lowerCount].ToLowerInvariant() + name[lowerCount..];
    }

    /// <summary>"fr-FR" → "frFR", "" → "invariant".</summary>
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
