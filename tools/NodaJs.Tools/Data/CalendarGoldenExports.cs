using NodaJs.Tools.Common;
using NodaTime;

namespace NodaJs.Tools.Data;

/// <summary>
/// Golden calendar data (test/golden/calendars/&lt;calendar&gt;.generated.ts), from NodaTime itself: for every year of
/// every calendar system, whether it's a leap year, its length, and the length of each month and its start (in days
/// from the start of the year). This stands in for NodaTime's tests that compare its calendars with the BCL's day by
/// day ("BclThroughHistory"): those prove NodaTime matches the BCL; matching NodaTime then matches it too.
/// <para>
/// Most years share their shape (e.g. every common year of a calendar), so a file lists the distinct shapes
/// (<c>yearTypes</c>) and gives each year's index into that list (<c>years</c>, from <c>minYear</c>). Days since the
/// epoch follow from <c>minDays</c> (the start of <c>minYear</c>) and each year's length.
/// </para>
/// </summary>
internal static class CalendarGoldenExports
{
    private const int IndexesPerLine = 40;

    public static void Run(GeneratedFiles output)
    {
        foreach (var calendar in CalendarSystem.Ids.OrderBy(id => id, StringComparer.Ordinal).Select(CalendarSystem.ForId))
            Write(output, calendar);
    }

    /// <summary>The file name for a calendar's golden files: its ID in lower case, with spaces as hyphens.</summary>
    internal static string FileName(CalendarSystem calendar) => calendar.Id.ToLowerInvariant().Replace(' ', '-');

    private static void Write(GeneratedFiles output, CalendarSystem calendar)
    {
        // NodaTime's internals: see NodaTimeInternals.
        var calculator = NodaTimeInternals.GetYearMonthDayCalculator(calendar);

        var types = new List<YearType>();
        var indexes = new List<int>();
        for (var year = calendar.MinYear; year <= calendar.MaxYear; year++)
        {
            var start = NodaTimeInternals.GetStartOfYearInDays(calculator, year);
            var months = Enumerable.Range(1, calendar.GetMonthsInYear(year)).ToList();
            var type = new YearType(
                calendar.IsLeapYear(year),
                calendar.GetDaysInYear(year),
                months.Select(m => calendar.GetDaysInMonth(year, m)).ToList(),
                months.Select(m => DaysSinceEpoch(new LocalDate(year, m, 1, calendar)) - start).ToList());
            var index = types.FindIndex(t => t.Equals(type));
            if (index < 0)
            {
                index = types.Count;
                types.Add(type);
            }
            indexes.Add(index);
        }
        var minDays = NodaTimeInternals.MinDays(calendar);
        var maxDays = NodaTimeInternals.MaxDays(calendar);

        var body = new TypescriptWriter()
            .WriteLine("import type { CalendarGolden } from \"../types.ts\";", emptyLineAfter: true)
            .OpenBlock("export const golden: CalendarGolden = {")
            .Property("id", Ts.Str(calendar.Id))
            .Property("minYear", Ts.Int(calendar.MinYear))
            .Property("maxYear", Ts.Int(calendar.MaxYear))
            .Property("minDays", Ts.Int(minDays))
            .Property("maxDays", Ts.Int(maxDays))
            .OpenBlock("yearTypes: [");
        foreach (var type in types)
            body.WriteLine("{ " +
                           $"leap: {Ts.Bool(type.Leap)}, " +
                           $"days: {type.Days}, " +
                           $"monthLengths: [{string.Join(", ", type.MonthLengths)}], " +
                           $"monthStarts: [{string.Join(", ", type.MonthStarts)}] " +
                           "},");
        body.CloseBlock("],")
            .OpenBlock("years: [");
        for (var i = 0; i < indexes.Count; i += IndexesPerLine)
            body.WriteLine(string.Join(", ", indexes.Skip(i).Take(IndexesPerLine)) + ",");
        body.CloseBlock("],")
            .CloseBlock("};");
        output.Write($"test/golden/calendars/{FileName(calendar)}.generated.ts", "golden", body,
            [$"NodaTime's {calendar.Id} calendar: every year's type (leap, length, month lengths and starts)."]);
    }

    private static int DaysSinceEpoch(LocalDate date) => NodaTimeInternals.DaysSinceEpoch(ref date);

    private sealed record YearType(bool Leap, int Days, IReadOnlyList<int> MonthLengths, IReadOnlyList<int> MonthStarts)
    {
        public bool Equals(YearType? other) =>
            other is not null && Leap == other.Leap && Days == other.Days &&
            MonthLengths.SequenceEqual(other.MonthLengths) && MonthStarts.SequenceEqual(other.MonthStarts);

        public override int GetHashCode() => HashCode.Combine(Leap, Days, MonthLengths.Count);
    }
}
