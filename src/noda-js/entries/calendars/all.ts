// noda-js/calendars/all: every calendar system outside the core (ISO, Gregorian, Julian and Coptic are always in
// CalendarSystem): the exports of noda-js/calendars/hebrew, /islamic, /persian, /umalqura and /badi. Importing this
// module registers them all, so CalendarSystem.ForId and CalendarSystem.Ids include them. To keep bundles small,
// import only the calendars an app uses instead.

export * from "./hebrew.ts";
export * from "./islamic.ts";
export * from "./persian.ts";
export * from "./umalqura.ts";
export * from "./badi.ts";
