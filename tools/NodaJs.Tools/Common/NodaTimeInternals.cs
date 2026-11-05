using System.Runtime.CompilerServices;
using System.Xml.Linq;
using NodaTime;
using NodaTime.TimeZones.Cldr;
using NUnit.Framework.Internal;

namespace NodaJs.Tools.Common;

/// <summary>
/// The non-public members of NodaTime (and its tzdb compiler, NUnit and the .NET runtime) that the tools use, as
/// <see cref="UnsafeAccessorAttribute"/> declarations: typed, direct calls instead of reflection. The runtime binds each
/// name when it's first called, so a member that's been renamed or removed upstream fails there with a
/// MissingMethodException or MissingFieldException naming it.
/// </summary>
internal static class NodaTimeInternals
{
    // The inaccessible types the accessors use, as assembly-qualified names (UnsafeAccessorType).
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

    /// <summary><c>LocalDate.DaysSinceEpoch</c> (internal).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_DaysSinceEpoch")]
    public static extern int DaysSinceEpoch(ref LocalDate date);

    /// <summary><c>CalendarSystem.YearMonthDayCalculator</c> (internal, of an internal type).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_YearMonthDayCalculator")]
    [return: UnsafeAccessorType(YearMonthDayCalculator)]
    public static extern object GetYearMonthDayCalculator(CalendarSystem calendar);

    /// <summary><c>CalendarSystem.MinDays</c> (internal).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_MinDays")]
    public static extern int MinDays(CalendarSystem calendar);

    /// <summary><c>CalendarSystem.MaxDays</c> (internal).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "get_MaxDays")]
    public static extern int MaxDays(CalendarSystem calendar);

    /// <summary><c>YearMonthDayCalculator.GetStartOfYearInDays(int)</c> (internal, virtual).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Method, Name = "GetStartOfYearInDays")]
    public static extern int GetStartOfYearInDays([UnsafeAccessorType(YearMonthDayCalculator)] object calculator, int year);

    /// <summary><c>UmAlQuraYearMonthDayCalculator.MonthLengths</c> (private static, set by the static constructor).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "MonthLengths")]
    public static extern ref ushort[] UmAlQuraMonthLengths([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    /// <summary><c>UmAlQuraYearMonthDayCalculator.YearLengths</c> (private static, set by the static constructor).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearLengths")]
    public static extern ref int[] UmAlQuraYearLengths([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    /// <summary><c>UmAlQuraYearMonthDayCalculator.YearStartDays</c> (private static, set by the static constructor).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearStartDays")]
    public static extern ref int[] UmAlQuraYearStartDays([UnsafeAccessorType(UmAlQuraYearMonthDayCalculator)] object? type);

    /// <summary><c>BadiYearMonthDayCalculator.YearInfoRaw</c> (private static).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "YearInfoRaw")]
    public static extern ref byte[] BadiYearInfoRaw([UnsafeAccessorType(BadiYearMonthDayCalculator)] object? type);

    /// <summary><c>PersianYearMonthDayCalculator.Astronomical.AstronomicalLeapYearBits</c> (private static).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticField, Name = "AstronomicalLeapYearBits")]
    public static extern ref byte[] PersianAstronomicalLeapYearBits([UnsafeAccessorType(PersianAstronomicalCalculator)] object? type);

    /// <summary>NodaTime.TzdbCompiler's entry point, <c>Program.Main</c> (private, in an internal class).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "Main")]
    public static extern Task<int> TzdbCompilerMain([UnsafeAccessorType(TzdbCompilerProgram)] object? type, string[] arguments);

    /// <summary>NodaTime.TzdbCompiler's <c>CldrWindowsZonesParser.Parse(XDocument)</c> (internal).</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "Parse")]
    public static extern WindowsZones ParseCldrWindowsZones([UnsafeAccessorType(CldrWindowsZonesParser)] object? type, XDocument document);

    /// <summary>NUnit's <c>TestMethod.Parms</c> (internal): a test case's parameters, including its expected result.</summary>
    [UnsafeAccessor(UnsafeAccessorKind.Field, Name = "Parms")]
    public static extern ref TestCaseParameters? Parms(TestMethod method);

    /// <summary>The .NET runtime's <c>Interop.Globalization.GetICUVersion()</c> (internal): the ICU version, packed.</summary>
    [UnsafeAccessor(UnsafeAccessorKind.StaticMethod, Name = "GetICUVersion")]
    public static extern int GetIcuVersion([UnsafeAccessorType(GlobalizationInterop)] object? type);
}
