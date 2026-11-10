using System.Globalization;
using System.Numerics;
using System.Text;

namespace NodaJs.Tools.Common;

/// <summary>Dart source literals.</summary>
public static class Dart
{
    /// <summary>The largest integer exact on dart2js (a JS number).</summary>
    public const long MaxSafeInteger = 9007199254740991;

    public static string Str(string? value)
    {
        if (value is null)
            return "null";
        var builder = new StringBuilder(value.Length + 2);
        builder.Append('\'');
        foreach (var c in value)
            switch (c)
            {
                case '\'': builder.Append(@"\'"); break;
                case '\\': builder.Append(@"\\"); break;
                case '$': builder.Append(@"\$"); break;
                case '\n': builder.Append(@"\n"); break;
                case '\r': builder.Append(@"\r"); break;
                case '\t': builder.Append(@"\t"); break;
                default:
                    // The same characters Ts.Str escapes.
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
        builder.Append('\'');
        return builder.ToString();
    }

    public static string Bool(bool value) => value ? "true" : "false";

    public static bool IsSafeInteger(BigInteger value) => BigInteger.Abs(value) <= MaxSafeInteger;

    /// <summary>An <c>int</c> literal, or <c>int.parse('...')</c> (not const) beyond ±2^53, which dart2js rejects.</summary>
    public static string Int(long value) => Int((BigInteger) value);

    /// <inheritdoc cref="Int(long)"/>
    public static string Int(BigInteger value)
    {
        var text = value.ToString(CultureInfo.InvariantCulture);
        if (IsSafeInteger(value))
            return text;
        // Beyond 64 bits (a ulong above long.MaxValue): a BigInt.
        return value >= long.MinValue && value <= long.MaxValue ? $"int.parse('{text}')" : BigInt(value);
    }

    public static string BigInt(BigInteger value) => $"BigInt.parse('{value.ToString(CultureInfo.InvariantCulture)}')";

    /// <summary>False for the <c>.parse('</c> calls (a string containing that only costs a <c>const</c>).</summary>
    public static bool IsConstant(string expression) => !expression.Contains(".parse('", StringComparison.Ordinal);

    /// <summary>A round-tripping double literal, always with a '.' or exponent.</summary>
    public static string Double(double value)
    {
        if (double.IsNaN(value)) return "double.nan";
        if (double.IsPositiveInfinity(value)) return "double.infinity";
        if (double.IsNegativeInfinity(value)) return "double.negativeInfinity";
        if (value == 0 && double.IsNegative(value)) return "-0.0";
        
        var text = value
            .ToString("R", CultureInfo.InvariantCulture)
            .Replace("E+", "e")
            .Replace("E-", "e-");
        return text.Contains('.') || text.Contains('e') ? text : text + ".0";
    }

    public static string TypeName(Type type) => 
        type == typeof(string) || type == typeof(char) ? "String" :
        type == typeof(bool) ? "bool" :
        type == typeof(double) || type == typeof(float) ? "double" :
        "int";
}
