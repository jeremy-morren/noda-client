using System.Numerics;

namespace NodaJs.Tools.Common;

/// <summary>A .NET value for the generated tests: a primitive, a list, or a tagged object.</summary>
public abstract record EncodedValue
{
    public static readonly EncodedValue Null = new NullValue();

    public static EncodedValue Bool(bool value) => new BoolValue(value);

    public static EncodedValue String(string? value) => value is null ? Null : new StringValue(value);

    public static EncodedValue Int(long value) => new IntegerValue(value, false);

    /// <summary>A .NET BigInteger/Int128.</summary>
    public static EncodedValue BigInt(BigInteger value) => new IntegerValue(value, true);

    public static EncodedValue Double(double value) => new DoubleValue(value);

    public static EncodedValue List(IEnumerable<EncodedValue> items) => new ListValue([.. items]);

    /// <summary>Parts from an anonymous object (<c>new { year = ..., calendar = (EncodedValue?) null }</c>): nulls left out.</summary>
    public static EncodedValue Tag(string tag, object parts) => new TaggedValue(tag, NamedValue<EncodedValue>.FromObject(parts));

    public static EncodedValue Tag(string tag, IEnumerable<NamedValue<EncodedValue>> parts) => new TaggedValue(tag, [.. parts]);

    /// <summary>Has an integer beyond ±2^53 (not a BigInt): the Dart harness skips the case on dart2js.</summary>
    public bool ExceedsDoublePrecision => this switch
    {
        IntegerValue i => !i.IsBigInt && !Dart.IsSafeInteger(i.Value),
        ListValue l => l.Items.Any(i => i.ExceedsDoublePrecision),
        TaggedValue t => t.Parts.Any(p => p.Value.ExceedsDoublePrecision),
        _ => false,
    };

    public bool IsDartConstant => this switch
    {
        IntegerValue i => !i.IsBigInt && Dart.IsSafeInteger(i.Value),
        ListValue l => l.Items.All(i => i.IsDartConstant),
        TaggedValue t => t.Parts.All(p => p.Value.IsDartConstant),
        _ => true,
    };

    public sealed record NullValue : EncodedValue;

    public sealed record BoolValue(bool Value) : EncodedValue;

    public sealed record StringValue(string Value) : EncodedValue;

    public sealed record IntegerValue(BigInteger Value, bool IsBigInt) : EncodedValue;

    public sealed record DoubleValue(double Value) : EncodedValue;

    public sealed record ListValue(IReadOnlyList<EncodedValue> Items) : EncodedValue;

    public sealed record TaggedValue(string TagName, IReadOnlyList<NamedValue<EncodedValue>> Parts) : EncodedValue;
}
