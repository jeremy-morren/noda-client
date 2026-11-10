using System.Text;

namespace NodaJs.Tools.Common;

/// <summary>An <see cref="EncodedValue"/> as Dart (shapes in dart/noda_dart/test/scenarios/types.dart).</summary>
public static class DartValueEncoder
{
    public static string Render(EncodedValue value) => value switch
    {
        EncodedValue.NullValue => "null",
        EncodedValue.BoolValue b => Dart.Bool(b.Value),
        EncodedValue.StringValue s => Dart.Str(s.Value),
        EncodedValue.IntegerValue { IsBigInt: true } i => Dart.BigInt(i.Value),
        EncodedValue.IntegerValue i => Dart.Int(i.Value),
        EncodedValue.DoubleValue d => Dart.Double(d.Value),
        EncodedValue.ListValue l => "[" + string.Join(", ", l.Items.Select(Render)) + "]",
        EncodedValue.TaggedValue t => Tag(t),
        _ => throw new ArgumentException($"Unknown encoded value {value}"),
    };

    private static string Tag(EncodedValue.TaggedValue value)
    {
        var builder = new StringBuilder();
        builder.Append("{r'$': ").Append(Dart.Str(value.TagName));
        foreach (var part in value.Parts)
            builder.Append(", ").Append(Dart.Str(part.Name)).Append(": ").Append(Render(part.Value));
        builder.Append('}');
        return builder.ToString();
    }
}
