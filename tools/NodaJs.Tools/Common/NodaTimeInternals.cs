using System.Runtime.CompilerServices;
using System.Xml.Linq;
using NodaTime;
using NodaTime.TimeZones.Cldr;
using NUnit.Framework.Internal;

namespace NodaJs.Tools.Common;

/// <summary>Non-public members the tools use; one renamed upstream fails on first call with a Missing*Exception.</summary>
internal static class NodaTimeInternals
{
    private const string NodaTimeAssembly = ", NodaTime";
    private const string TzdbCompilerAssembly = ", NodaTime.TzdbCompiler";
    private const string CalendarsNamespace = "NodaTime.Calendars.";

    private const string YearMonthDayCalculator = $"{CalendarsNamespace}YearMonthDayCalculator{NodaTimeAssembly}";
    private const string UmAlQuraYearMonthDayCalculator = $"{CalendarsNamespace}UmAlQuraYearMonthDayCalculator{NodaTimeAssembly}";
    private const string BadiYearMonthDayCalculator = $"{CalendarsNamespace}BadiYearMonthDayCalculator{NodaTimeAssembly}";
    private const string PersianAstronomicalCalculator = $"{CalendarsNamespace}PersianYearMonthDayCalculator+Astronomical{NodaTimeAssembly}";
    private const string TzdbCompilerProgram = $"NodaTime.TzdbCompiler.Program{TzdbCompilerAssembly}";
    private const string CldrWindowsZonesParser = $"NodaTime.TzdbCompiler.Tzdb.CldrWindowsZonesParser{TzdbCompilerAssembly}";
    private const string GlobalizationInterop = "Interop+Globalization, System.Private.CoreLib";

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_DaysSinceEpoch")]
    public static extern int DaysSinceEpoch(ref LocalDate date);

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_YearMonthDayCalculator")]
    [return: UnsafeAccessorType(YearMonthDayCalculator)]
    public static extern object GetYearMonthDayCalculator(CalendarSystem calendar);

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_MinDays")]
    public static extern int MinDays(CalendarSystem calendar);

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_MaxDays")]
    public static extern int MaxDays(CalendarSystem calendar);

    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "GetStartOfYearInDays")]
    public static extern int GetStartOfYearInDays([UnsafeAccessorType(YearMonthDayCalculator)] object calculator, int year);

    // Set by the static constructor.
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "MonthLengths")]
    public static extern ref ushort[] UmAlQuraMonthLengths([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearLengths")]
    public static extern ref int[] UmAlQuraYearLengths([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearStartDays")]
    public static extern ref int[] UmAlQuraYearStartDays([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearInfoRaw")]
    public static extern ref byte[] BadiYearInfoRaw([UnsafeAccessorType(BadiYearMonthDayCalculator)] object? type);

    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "AstronomicalLeapYearBits")]
    public static extern ref byte[] PersianAstronomicalLeapYearBits([UnsafeAccessorType(PersianAstronomicalCalculator)] object? type);

    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "Main")]
    public static extern Task<int> TzdbCompilerMain([UnsafeAccessorType(TzdbCompilerProgram)] object? type, string[] arguments);

    // The version comes from a "windowsZones-<version>.xml" file name, else from the document.
    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "Parse")]
    public static extern WindowsZones ParseCldrWindowsZones([UnsafeAccessorType(CldrWindowsZonesParser)] object? type, XDocument document, string file);

    [UnsafeAccessor(UnsafeAccessorKind.Field, Name = "Parms")]
    public static extern ref TestCaseParameters? Parms(TestMethod method);

    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "GetICUVersion")]
    public static extern int GetIcuVersion([UnsafeAccessorType(GlobalizationInterop)] object? type);
}
