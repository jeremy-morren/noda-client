using System.Globalization;
using NodaJs.Tools.Common;
using NodaTime;

namespace NodaJs.Tools.Data;

/// <summary>
/// Every year of every calendar (leap, length, month lengths and starts), as distinct year types and each year's index.
/// Stands in for NodaTime's "BclThroughHistory" tests.
/// </summary>
internal static class CalendarGoldenExports
{
    private const int IndexesPerLine = 40;

    public static void Run(GeneratedFiles output)
    {
        foreach (var calendar in CalendarSystem.Ids.OrderBy(id => id, StringComparer.Ordinal).Select(CalendarSystem.ForId))
            Write(output, calendar);
    }

    internal static string FileName(CalendarSystem calendar) => calendar.Id.ToLowerInvariant().Replace(' ', '-');

    private static void Write(GeneratedFiles output, CalendarSystem calendar)
    {
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

        foreach (var port in LangTarget.All)
        {
            var body = port.NewWriter();
            body.OpenConstObject("golden", "CalendarGolden", "../types", constant: true)
                .Property("id", body.Str(calendar.Id))
                .Property("minYear", body.Int(calendar.MinYear))
                .Property("maxYear", body.Int(calendar.MaxYear))
                .Property("minDays", body.Int(minDays))
                .Property("maxDays", body.Int(maxDays))
                .OpenBlock("yearTypes: [");
            foreach (var type in types)
                body.WriteLine(body.Object("CalendarYearType", new
                {
                    leap = body.Bool(type.Leap),
                    days = type.Days.ToString(CultureInfo.InvariantCulture),
                    monthLengths = body.List(type.MonthLengths.Select(l => l.ToString(CultureInfo.InvariantCulture))),
                    monthStarts = body.List(type.MonthStarts.Select(s => s.ToString(CultureInfo.InvariantCulture))),
                }) + ",");
            body.CloseBlock("],")
                .OpenBlock("years: [");
            for (var i = 0; i < indexes.Count; i += IndexesPerLine)
                body.WriteLine(string.Join(", ", indexes.Skip(i).Take(IndexesPerLine)) + ",");
            body.CloseBlock("],")
                .CloseConstObject();
            output.Write(port.Test($"golden/calendars/{FileName(calendar)}"), "golden", body,
                [$"NodaTime's {calendar.Id} calendar: every year's type (leap, length, month lengths and starts)."]);
        }
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
