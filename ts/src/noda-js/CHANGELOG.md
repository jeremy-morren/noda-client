# noda-js Changelog
All notable changes to noda-js and the npm packages released with it (noda-js-zod, the Windows native addon packages)
are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), kept with
[keep-a-changelog](https://github.com/oscarotero/keep-a-changelog) (`node scripts/changelog/changelog.ts`): add changes
under Unreleased as they're merged; releasing turns it into the version's section.

## Unreleased
### Added
- System time zones (`noda-js/system`) and the Windows native addon packages.
- Exact values beyond 2⁵³ use native `BigInt` wherever the engine has it, and long.js only where it doesn't (picked
  when noda-js loads; same API and results). Tested on Node.js 8, QuickJS 2019-12-21 and Chromium 66 (no `BigInt`),
  and through esbuild, Rollup, webpack 5, Vite, Parcel 2 and Bun.

### Changed
- Follows NodaTime's main branch instead of its 3.3 release: the Persian arithmetic calendar's leap years before 474,
  week-year 0 in the Badíʿ calendar, `Period.Between` with nanosecond units, and case-insensitive month and day names
  (by unambiguous prefix) in the tzdb compiler.

### Fixed
- With webpack and Parcel (which took the internal module barrel as side-effect free), noda-js failed to load
  ("Cannot access ... before initialization").
- On engines with WebAssembly, long.js gave `a / -1 = a` for exact values within 2³² of `long.MinValue`, so checked
  multiplication or division of such a value by -1 could throw an `OverflowException` or give the wrong value.
