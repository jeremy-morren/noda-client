// A workload run on built noda-js in other engines (ES2015 source), compared with its results on src/.
// No imports: scripts outside Vitest import this too.

export const workloadSource = String.raw`function (N) {
  var results = {};
  function check(name, fn) {
    try {
      results[name] = String(fn());
    } catch (e) {
      results[name] = "error: " + (e && e.name) + ": " + (e && e.message);
    }
  }
  check("long", function () {
    var exact = N.Period.FromNanoseconds("9007199254740993").ExactNanoseconds;
    if (exact === null || typeof exact !== "object") return typeof exact;
    return typeof exact.value === "bigint" ? "bigint" : "unsigned" in exact && "high" in exact ? "long.js" : "unknown";
  });
  var big = N.Period.FromNanoseconds("9007199254740993");
  check("periodNanoseconds", function () { return big.toString(); });
  check("periodSum", function () { return N.Period.Add(big, big).toString(); });
  check("periodNegate", function () { return N.Period.Negate(N.Period.FromTicks("9223372036854775807")).toString(); });
  check("periodNormalize", function () { return N.Period.FromNanoseconds("9223372036854775807").Normalize().toString(); });
  check("periodTicksBetween", function () {
    return N.Period.Between(new N.LocalDateTime(1, 1, 1, 0, 0), new N.LocalDateTime(9999, 12, 31, 23, 59, 59), N.PeriodUnits.Ticks).toString();
  });
  check("periodParse", function () { return N.PeriodPattern.Roundtrip.Parse("PT-9223372036854775808S").Value.toString(); });
  check("periodParseOverflow", function () { return N.PeriodPattern.Roundtrip.Parse("PT9223372036854775808S").Success; });
  check("periodOverflow", function () { return N.Period.Add(N.Period.FromSeconds("9223372036854775807"), N.Period.FromSeconds(1)).toString(); });
  check("periodToDuration", function () { return N.Period.FromTicks("9007199254740993").ToDuration().toString(); });
  check("durationMax", function () { return N.Duration.FromNanoseconds("9223372036854775807").toString(); });
  check("durationMin", function () { return N.Duration.FromTicks("-9223372036854775808").toString(); });
  check("durationMultiply", function () { return N.Duration.Multiply(N.Duration.FromNanoseconds("3037000499"), "3037000499").toString(); });
  check("durationDivide", function () { return N.Duration.Divide(N.Duration.FromNanoseconds("9223372036854775807"), 7).toString(); });
  check("durationInt64", function () { return N.Duration.FromNanoseconds("9007199254740993").ToInt64Nanoseconds(); });
  check("durationBeyondLong", function () { return N.Duration.FromDays(16777215).Plus(N.Duration.Epsilon).toString(); });
  check("durationPattern", function () { return N.DurationPattern.Roundtrip.Format(N.Duration.FromNanoseconds("-9223372036854775808")); });
  check("instantTicks", function () { return N.Instant.FromUnixTimeTicks("2534023007999999999").toString(); });
  check("instantToTicks", function () { return N.Instant.FromUtc(9999, 12, 31, 23, 59, 59).ToUnixTimeTicks(); });
  check("instantMinus", function () { return N.Instant.FromUtc(9999, 12, 31, 0, 0).Minus(N.Instant.FromUtc(-9998, 1, 1, 0, 0)).toString(); });
  var instant = N.Instant.FromUtc(2024, 7, 1, 12, 0);
  check("tzdbVersion", function () { return N.tzdb.VersionId; });
  check("madrid", function () { return instant.InZone(N.tzdb.Get("Europe/Madrid")).toString(); });
  check("sydney", function () { return instant.InZone(N.tzdb.Get("Australia/Sydney")).toString(); });
  check("gap", function () { return new N.LocalDate(2024, 3, 31).At(new N.LocalTime(2, 30)).InZoneLeniently(N.tzdb.Get("Europe/Madrid")).toString(); });
  check("zonedPattern", function () {
    return N.ZonedDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd'T'HH:mm:ss z '('o<g>')'", N.tzdb)
      .Format(N.Instant.FromUtc(2024, 3, 1, 12, 0).InZone(N.tzdb.Get("Europe/London")));
  });
  check("spanish", function () { return N.LocalDatePattern.Create("d 'de' MMMM 'de' uuuu", N.esES).Format(new N.LocalDate(2024, 7, 1)); });
  check("parseLocalDateTime", function () { return N.LocalDateTimePattern.ExtendedIso.Parse("2024-02-29T23:59:59.123456789").Value.toString(); });
  check("json", function () { return JSON.stringify({ at: instant, on: new N.LocalDate(2024, 7, 1), zoned: instant.InZone(N.tzdb.Get("Europe/Madrid")) }); });
  return results;
}`;

export function runWorkload(noda: object): Record<string, string> {
  const run = new Function(`return (${workloadSource});`)() as (n: object) => Record<string, string>;
  return run(noda);
}

/** Exact results beyond 2^53, so any rounding shows. */
export const literalWorkload: Record<string, string> = {
  periodNanoseconds: "PT9007199254740993n",
  periodSum: "PT18014398509481986n",
  periodParse: "PT-9223372036854775808S",
  durationMax: "106751:23:47:16.854775807",
  durationMultiply: "106751:23:47:10.926249001",
  durationMin: "-10675199:02:48:05.4775808",
  periodNegate: "PT-9223372036854775807t",
  periodTicksBetween: "PT3155378975990000000t",
  durationInt64: "9007199254740992",
  instantTicks: "9999-12-31T23:59:59Z",
  instantToTicks: "2534023007990000000",
  periodOverflow: "error: OverflowException: Arithmetic operation resulted in an overflow.",
  madrid: "2024-07-01T14:00:00 Europe/Madrid (+02)",
  zonedPattern: "2024-03-01T12:00:00 Europe/London (+00)",
};
