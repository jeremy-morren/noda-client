using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

/// <summary>
/// The data tables NodaTime's calendar calculators embed in their source (as base64 strings, decoded when the class is
/// initialized): read from the initialized static fields and written as JSON arrays, so the ported
/// calculators import the decoded values instead of decoding anything.
/// <para>
/// Each table goes to src/noda-js/Calendars/&lt;Calculator&gt;Data.generated.ts, a leaf module (no imports) that the
/// calculator imports directly, with one <c>export const</c> per field, under the field's C# name.
/// </para>
/// </summary>
internal static class CalendarDataExports
{
    // Numbers per line of a written array.
    private const int ValuesPerLine = 20;

    public static void Run(GeneratedFiles output)
    {
        // NodaTime's internals: see NodaTimeInternals. Reading a static field runs the class's static initialization,
        // which decodes the table.
        Write(output, "NodaTime.Calendars.UmAlQuraYearMonthDayCalculator", "UmAlQuraYearMonthDayCalculatorData",
            ("MonthLengths", NodaTimeInternals.UmAlQuraMonthLengths(null)),
            ("YearLengths", NodaTimeInternals.UmAlQuraYearLengths(null)),
            ("YearStartDays", NodaTimeInternals.UmAlQuraYearStartDays(null)));
        Write(output, "NodaTime.Calendars.BadiYearMonthDayCalculator", "BadiYearMonthDayCalculatorData",
            ("YearInfoRaw", NodaTimeInternals.BadiYearInfoRaw(null)));
        Write(output, "NodaTime.Calendars.PersianYearMonthDayCalculator+Astronomical", "PersianYearMonthDayCalculatorAstronomicalData",
            ("AstronomicalLeapYearBits", NodaTimeInternals.PersianAstronomicalLeapYearBits(null)));
    }

    /// <summary>src/noda-js/Calendars/&lt;file&gt;.generated.ts, with one array per field.</summary>
    private static void Write(GeneratedFiles output, string typeName, string file, params (string Name, Array Values)[] fields)
    {
        var writer = new TypescriptWriter();
        foreach (var (name, values) in fields)
            WriteArray(writer, name, values.GetType().GetElementType()!.Name, values.Cast<object>().Select(Convert.ToInt64).ToList());
        output.Write($"src/noda-js/Calendars/{file}.generated.ts", "calendars", writer,
            [$"Source: {typeName} (static fields {string.Join(", ", fields.Select(f => f.Name))}, as initialized)"]);
    }

    /// <summary>
    /// <c>export const Name: readonly number[] = [...];</c>, the array literal being a JSON array, wrapped at
    /// <see cref="ValuesPerLine"/> values per line.
    /// </summary>
    private static void WriteArray(TypescriptWriter writer, string name, string elementType, IReadOnlyList<long> values)
    {
        writer.DocComment($"C#: {elementType}[] {name} ({values.Count} values).")
            .OpenBlock($"export const {name}: readonly number[] = [");
        for (var i = 0; i < values.Count; i += ValuesPerLine)
        {
            var line = string.Join(", ", values.Skip(i).Take(ValuesPerLine).Select(Ts.SourceInt));
            writer.WriteLine(i + ValuesPerLine < values.Count ? line + "," : line);
        }
        writer.CloseBlock("];", emptyLineAfter: true);
    }
}
