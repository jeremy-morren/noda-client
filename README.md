# noda-client: NodaTime for TypeScript and Dart

Line-for-line ports of [NodaTime](https://nodatime.org), the date and time library for .NET, with NodaTime's API,
text formats, time zones and calendars, and NodaTime's own tests:

| Port | Folder | Package | Runs on |
|---|---|---|---|
| **noda-js** (TypeScript) | [`ts/`](ts/README.md) | [`noda-js`](https://www.npmjs.com/package/noda-js) on npm | any JavaScript engine (ES2015): browsers, Node, Bun, Deno, React Native (Hermes), embedded engines |
| **noda_dart** (Dart) | [`dart/noda_dart/`](dart/noda_dart/README.md) | `noda_dart` on pub.dev | everywhere Flutter and Dart run: Android, iOS, Windows, macOS, Linux, the web (dart2js and dart2wasm) |

Both follow NodaTime's main branch, and both are generated, as far as possible, from NodaTime itself by the .NET
tools in [`tools/`](tools/README.md): enums, constants, culture data, calendar tables, the tz database, and every
test case of NodaTime's test suite. See [AGENTS.md](AGENTS.md) for how the repository works.

[![CI](https://github.com/jeremy-morren/noda-client/actions/workflows/draft-release.yml/badge.svg?branch=main)](https://github.com/jeremy-morren/noda-client/actions/workflows/draft-release.yml?query=branch%3Amain)
[![Release](https://img.shields.io/github/v/release/jeremy-morren/noda-client)](https://github.com/jeremy-morren/noda-client/releases/latest)

Licensed under Apache-2.0, like NodaTime. See [NOTICE.txt](NOTICE.txt) for data licences.
