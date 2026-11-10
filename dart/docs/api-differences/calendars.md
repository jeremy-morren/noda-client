# API differences: calendars (`CalendarSystem`, `YearMonthDay*`, `Calendars/`, `Fields/`)

| C# | Dart | Why |
|---|---|---|
| `IWeekYearRule` extension methods `WeekYearRuleExtensions.GetLocalDate(rule, weekYear, week, dayOfWeek)`, `GetWeeksInWeekYear(rule, weekYear)` | `extension WeekYearRuleExtensions on IWeekYearRule` with the same names; call as `WeekYearRuleExtensions(rule).GetLocalDate(weekYear, week, dayOfWeek)` | The interface's members of the same names hide the extension's. |
| `WeekYearRules.ForMinDaysInFirstWeek(int)`, `ForMinDaysInFirstWeek(int, IsoDayOfWeek)` | `ForMinDaysInFirstWeek(int minDaysInFirstWeek, [IsoDayOfWeek firstDayOfWeek = IsoDayOfWeek.Monday])` | Prefix chain → optional parameter. |
| `WeekYearRules.FromCalendarWeekRule(CalendarWeekRule, DayOfWeek)` | `FromCalendarWeekRule(int calendarWeekRule, int firstDayOfWeek)` | No such Dart types: .NET's values (0 FirstDay, 1 FirstFullWeek, 2 FirstFourDayWeek; 0 Sunday … 6 Saturday). |
| `CalendarSystem.ForId` throws `KeyNotFoundException` | throws `ArgumentError` | Exception mapping. |
| `CalendarSystem.Ids` (`IEnumerable<string>`) | `Iterable<String>` | |
| `CalendarSystem.Eras` (`IList<Era>`), `EraCalculator.Eras` (`ReadOnlyCollection<Era>`) | `List<Era>` (unmodifiable) | |
| `Era.Common` etc. (static properties) | `static final` fields | |
| internal `YearMonthDayCalculator.GetYearMonthDay(int daysSinceEpoch)` | `GetYearMonthDayDaysSinceEpoch(int)` | Overload of `GetYearMonthDay(int, int)`. |
| internal `YearMonthDayCalculator.GetYear(int, out int zeroBasedDayOfYear)` | `(int, int) GetYear(int)` (year, zeroBasedDayOfYear) | `out` → record. |
| internal `TimePeriodField.Add(LocalTime, long)`, `Add(LocalTime, long, ref int extraDays)` | `AddLocalTime(LocalTime, int)`, `(LocalTime, int) AddLocalTimeExtraDays(LocalTime, int, int extraDays)` | Overloads; `ref` → returned in a record. `Add(LocalDateTime, long)` keeps `Add`. |
| internal `YearMonthDayCalendar(int yearMonthDay, CalendarOrdinal)` and `YearMonthDayCalendar(int year, int month, int day, CalendarOrdinal)` | one factory `YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(int, Object, [int? day, CalendarOrdinal? calendarOrdinal])`, told apart by argument count | Both constructors have the same mechanical name (`New` + parameter names). |
| internal nested `PersianYearMonthDayCalculator.Simple`/`Arithmetic`/`Astronomical` | `PersianYearMonthDayCalculatorSimple` etc. | Nested types. |
| internal `YearMonthDay`/`YearMonthDayCalendar` `IComparable.CompareTo`, operators | `compareTo`, `<`, `<=`, `>`, `>=`, `==` | Dart protocol names. |
| `CalendarSystem.DebugValidateYearMonthDay` (`[Conditional("DEBUG")]`) | runs inside `assert` | Runs only when assertions are enabled. |
