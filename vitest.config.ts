import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig } from "vitest/config";

// The companion package (src/noda-js-zod) imports "noda-js". In tests that must be the core's
// sources, the same modules the tests import, not its build output (two copies of a class break instanceof).
// One alias per entry point in src/noda-js/package.json "exports" (test/tsconfig.json's `paths` mirror these).
const coreExports: Record<string, { default: string }> = JSON.parse(
  readFileSync(new URL("./src/noda-js/package.json", import.meta.url), "utf8"),
).exports;
const coreAliases = Object.entries(coreExports)
  // Longest first, so "noda-js/tzdb/bundled" wins over "noda-js/tzdb" and "noda-js".
  .sort(([a], [b]) => b.length - a.length)
  .map(([subpath, target]) => ({
    find: new RegExp(`^noda-js${subpath.slice(1).replace(/\//g, "\\/")}$`),
    replacement: fileURLToPath(new URL(`./src/noda-js/${target.default.replace("./dist/", "").replace(/\.js$/, ".ts")}`, import.meta.url)),
  }));

// Tests that need Node itself (node:fs, esbuild), so they only run in the `node` project.
const nodeOnly = [
  "test/bundle/tree-shaking.test.ts",
  "test/clock-isolation.test.ts",
  "test/unported.test.ts",
  "test/zod/tree-shaking.test.ts",
  // Removes globals (Intl, navigator, ...) and re-imports the library.
  "test/no-host-apis.test.ts",
  // Runs the single-file module in QuickJS (WebAssembly).
  "test/module/quickjs.test.ts",
];

export default defineConfig({
  // NZD and tzdata (.tar.gz) test fixtures are imported as assets (`?inline`), so they load the same way on Node and in browsers.
  assetsInclude: ["**/*.nzd", "**/*.tar.gz"],
  resolve: { alias: coreAliases },
  test: {
    include: ["test/**/*.test.ts"],
    // Registers every calendar system (noda-js/calendars/all) before each test file.
    setupFiles: ["./test/setup.ts"],
    // Every test runs on Node and, to catch engine and Intl differences, in the three browser engines (V8,
    // SpiderMonkey, JavaScriptCore) via Playwright. `npm run test:node` / `npm run test:browser` run one side.
    projects: [
      {
        extends: true,
        test: {
          name: "node",
          environment: "node",
        },
      },
      {
        extends: true,
        test: {
          // Each instance is a project of its own, named after its browser (so are test results).
          name: "browser",
          exclude: nodeOnly,
          browser: {
            enabled: true,
            provider: playwright(),
            headless: true,
            screenshotFailures: false,
            instances: [
              { browser: "chromium", name: "chromium" },
              { browser: "firefox", name: "firefox" },
              // One page at a time: with several pages open, Playwright's WebKit (seen on Windows) intermittently
              // never finishes loading a test file's iframe, and the run hangs. Sequential, it takes about a minute.
              { browser: "webkit", name: "webkit", maxWorkers: 1 },
            ],
          },
        },
      },
    ],
    // Used by `npm run test:ci` (--coverage); the CI workflow publishes the summaries. v8 coverage, from the node
    // project only (see test/vitest/v8-node-only-coverage.ts).
    coverage: {
      provider: "custom",
      customProviderModule: "./test/vitest/v8-node-only-coverage.ts",
      include: ["src/**/*.ts"],
      // Generated data (cultures, tzdb, enums, messages) isn't code worth measuring.
      exclude: ["src/**/*.generated.ts", "src/*/dist/**"],
      reporter: ["text-summary", "json-summary", "json"],
      reportsDirectory: "coverage",
      reportOnFailure: true,
    },
  },
});
