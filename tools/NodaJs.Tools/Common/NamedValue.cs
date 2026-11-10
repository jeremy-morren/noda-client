using System.Runtime.CompilerServices;

namespace NodaJs.Tools.Common;

/// <summary>A name and its value: a property of generated code, or a part of an <see cref="EncodedValue"/>.</summary>
public sealed record NamedValue<T>(string Name, T Value) where T : class
{
    /// <summary>An anonymous object's properties in declaration order, leaving out those whose value is null.</summary>
    public static IReadOnlyList<NamedValue<T>> FromObject(object parts)
    {
        var type = parts.GetType();
        if (!type.IsDefined(typeof(CompilerGeneratedAttribute), inherit: false) || !type.Name.Contains("AnonymousType"))
            throw new ArgumentException($"Expected an anonymous object, not {type}.", nameof(parts));
        return type.GetProperties()
            .Select(p => new { p.Name, Value = (T?) p.GetValue(parts) })
            .Where(p => p.Value is not null)
            .Select(p => new NamedValue<T>(p.Name, p.Value!))
            .ToList();
    }
}
