using System.Text;

namespace NodaJs.Tools.Common;

/// <summary>An <see cref="EncodedValue"/> as TS (shapes: <c>Encoded*</c> in ts/test/scenarios/types.ts).</summary>
public static class TsValueEncoder
{
    public static string Render(EncodedValue value) => value switch
    {
        EncodedValue.NullValue => "null",
        EncodedValue.BoolValue b => Ts.Bool(b.Value),
        EncodedValue.StringValue s => Ts.Str(s.Value),
        EncodedValue.IntegerValue i => Integer(i),
        EncodedValue.DoubleValue d => Ts.Double(d.Value),
        EncodedValue.ListValue l => "[" + string.Join(", ", l.Items.Select(Render)) + "]",
        EncodedValue.TaggedValue t => Tag(t),
        _ => throw new ArgumentException($"Unknown encoded value {value}"),
    };

    private static string Integer(EncodedValue.IntegerValue value) => value.IsBigInt ? Ts.BigInt(value.Value) : Ts.Int(value.Value);

    private static string Tag(EncodedValue.TaggedValue value)
    {
        var builder = new StringBuilder();
        builder.Append("{ $: ").Append(Ts.Str(value.TagName));
        foreach (var part in value.Parts)
            builder.Append(", ").Append(part.Name).Append(": ").Append(Render(part.Value));
        builder.Append(" }");
        return builder.ToString();
    }
}
