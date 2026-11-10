using NodaJs.Tools.Common;

namespace NodaJs.Tools.Data;

/// <summary>The tables NodaTime's calendar calculators decode from base64, as arrays, so the ports decode nothing.</summary>
internal static class CalendarDataExports
{
    private const int ValuesPerLine = 20;

    public static void Run(GeneratedFiles output)
    {
        // Reading a static field runs the static constructor, which decodes the table.
        Write(output, "NodaTime.Calendars.UmAlQuraYearMonthDayCalculator", "UmAlQuraYearMonthDayCalculatorData", new
        {
            MonthLengths = NodaTimeInternals.UmAlQuraMonthLengths(null),
            YearLengths = NodaTimeInternals.UmAlQuraYearLengths(null),
            YearStartDays = NodaTimeInternals.UmAlQuraYearStartDays(null),
        });
        Write(output, "NodaTime.Calendars.BadiYearMonthDayCalculator", "BadiYearMonthDayCalculatorData", new
        {
            YearInfoRaw = NodaTimeInternals.BadiYearInfoRaw(null),
        });
        Write(output, "NodaTime.Calendars.PersianYearMonthDayCalculator+Astronomical", "PersianYearMonthDayCalculatorAstronomicalData", new
        {
            AstronomicalLeapYearBits = NodaTimeInternals.PersianAstronomicalLeapYearBits(null),
        });
    }

    /// <summary><paramref name="arrays"/>: an anonymous object, a property per static field.</summary>
    private static void Write(GeneratedFiles output, string typeName, string file, object arrays)
    {
        var fields = NamedValue<Array>.FromObject(arrays);
        foreach (var port in LangTarget.All)
        {
            var writer = port.NewWriter();
            foreach (var field in fields)
                WriteArray(writer, field.Name, field.Value.GetType().GetElementType()!.Name, field.Value.Cast<object>().Select(Convert.ToInt64).ToList());
            output.Write(port.Source($"Calendars/{file}"), "calendars", writer,
                [$"Source: {typeName} (static fields {string.Join(", ", fields.Select(f => f.Name))}, as initialized)"]);
        }
    }

    private static void WriteArray(CodeWriter writer, string name, string elementType, IReadOnlyList<long> values)
    {
        var literals = values.Select(writer.SourceInt).ToList();
        writer.DocComment($"C#: {elementType}[] {name} ({values.Count} values).")
            .OpenBlock(writer switch
            {
                TypescriptWriter => $"export const {name}: readonly number[] = [",
                DartWriter => $"{(literals.All(Dart.IsConstant) ? "const" : "final")} List<int> {name} = [",
                _ => writer.ThrowUnknown<string>(),
            });
        for (var i = 0; i < values.Count; i += ValuesPerLine)
        {
            var line = string.Join(", ", literals.Skip(i).Take(ValuesPerLine));
            writer.WriteLine(i + ValuesPerLine < values.Count ? line + "," : line);
        }
        writer.CloseBlock("];", emptyLineAfter: true);
    }
}
