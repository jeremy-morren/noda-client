import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { playwright } from "@vitest/browser-playwright";
import { defineConfig, type Plugin, type TestProjectInlineConfiguration } from "vitest/config";

// "noda-js" resolves to the core's sources, not dist (two copies of a class break instanceof).
const coreExports: Record<string, { default: string }> = JSON.parse(
  readFileSync(new URL("./src/noda-js/package.json", import.meta.url), "utf8"),
).exports;
const coreAliases = Object.entries(coreExports)
  // Longest first.
  .sort(([a], [b]) => b.length - a.length)
  .map(([subpath, target]) => ({
    find: new RegExp(`^noda-js${subpath.slice(1).replace(/\//g, "\\/")}$`),
    replacement: fileURLToPath(new URL(`./src/noda-js/${target.default.replace("./dist/", "").replace(/\.js$/, ".ts")}`, import.meta.url)),
  }));

// node-longjs: swaps Utility/Long.ts for long.js, as on an engine without BigInt.
const longSelector = fileURLToPath(new URL("./src/noda-js/Utility/Long.ts", import.meta.url));
const longJsOnly = fileURLToPath(new URL("./test/helpers/LongJsOnly.ts", import.meta.url));
const samePath = (a: string, b: string): boolean => a.replace(/\\/g, "/").toLowerCase() === b.replace(/\\/g, "/").toLowerCase();
const longJsOnlyPlugin: Plugin = {
  name: "noda-js:long-js-only",
  enforce: "pre",
  async resolveId(source, importer, options) {
    if (!/(^|\/)Long\.ts$/.test(source)) {
      return null;
    }
    const resolved = await this.resolve(source, importer, { ...options, skipSelf: true });
    return resolved && samePath(resolved.id, longSelector) ? longJsOnly : resolved;
  },
};

// Tests that need Node itself.
const nodeOnly = [
  "test/bundle/tree-shaking.test.ts",
  "test/clock-isolation.test.ts",
  "test/unported.test.ts",
  "test/zod/tree-shaking.test.ts",
  "test/no-host-apis.test.ts",
  "test/module/quickjs.test.ts",
  "test/module/hermes.test.ts",
  "test/module/old-engines.test.ts",
  "test/bundlers/bundlers.test.ts",
];

// Tests that bundle noda-js themselves (the Long swap doesn't reach them; they check both implementations).
const ownBuilds = [
  "test/bundle/**",
  "test/zod/tree-shaking.test.ts",
  "test/module/**",
  "test/bundlers/**",
];

// Extra browser projects, enabled by NODA_TEST_BROWSERS (comma-separated). safari needs `sudo safaridriver --enable`
// once; ios-safari a simulator (NODA_TEST_IOS_UDID); android-chrome Appium at 127.0.0.1:4723 (scripts/test/test-android.ts).
const extraBrowserNames = ["edge", "safari", "ios-safari", "android-chrome"];
const extraBrowsers = new Set((process.env.NODA_TEST_BROWSERS ?? "").split(",").map((b) => b.trim()).filter(Boolean));
for (const name of extraBrowsers) {
  if (!extraBrowserNames.includes(name)) {
    throw new Error(`NODA_TEST_BROWSERS: unknown browser "${name}" (known: ${extraBrowserNames.join(", ")}).`);
  }
}

// One WebdriverIO session, slow: longer timeouts.
async function webdriverProject(): Promise<TestProjectInlineConfiguration[]> {
  const wanted = ["safari", "ios-safari", "android-chrome"].filter((b) => extraBrowsers.has(b));
  if (wanted.length === 0) {
    return [];
  }
  const { webdriverio } = await import("@vitest/browser-webdriverio");
  const iosCapabilities: Record<string, unknown> = {
    platformName: "iOS",
    "safari:useSimulator": true,
    ...(process.env.NODA_TEST_IOS_UDID ? { "safari:deviceUDID": process.env.NODA_TEST_IOS_UDID } : { "safari:deviceType": "iPhone" }),
  };
  const instances = {
    safari: { browser: "safari", name: "safari", provider: webdriverio() },
    "ios-safari": {
      browser: "safari",
      name: "ios-safari",
      provider: webdriverio({
        // Reuse the safaridriver scripts/devices/start-ios-simulator.ts started (a fresh one sometimes refuses connections).
        ...(process.env.NODA_TEST_SAFARIDRIVER_PORT
          ? { hostname: "127.0.0.1", port: Number(process.env.NODA_TEST_SAFARIDRIVER_PORT), path: "/" }
          : {}),
        capabilities: iosCapabilities,
        connectionRetryTimeout: 600_000,
      }),
    },
    "android-chrome": {
      browser: "chrome",
      name: "android-chrome",
      provider: webdriverio({
        hostname: "127.0.0.1",
        port: 4723,
        path: "/",
        connectionRetryTimeout: 600_000,
        capabilities: {
          "wdio:enforceWebDriverClassic": true,
          platformName: "Android",
          "appium:automationName": "UiAutomator2",
          "appium:newCommandTimeout": 3600,
          // Skip Chrome's first-run screens.
          "appium:chromeOptions": { args: ["--disable-fre", "--no-first-run", "--no-default-browser-check"] },
        },
      }),
    },
  } as const;
  return [
    {
      extends: true,
      test: {
        name: "webdriver",
        exclude: nodeOnly,
        testTimeout: 60_000,
        hookTimeout: 300_000,
        // Fixed: scripts/test/test-android.ts forwards it to the emulator (adb reverse).
        api: { host: "127.0.0.1", port: Number(process.env.NODA_TEST_API_PORT || 23400), strictPort: true },
        browser: {
          enabled: true,
          headless: false,
          connectTimeout: 300_000,
          screenshotFailures: false,
          instances: wanted.map((b) => instances[b as keyof typeof instances]),
        },
      },
    },
  ];
}

// "@testdata/x": the repository's testdata/ (shared with noda_dart).
const testDataAlias = { find: /^@testdata\//, replacement: fileURLToPath(new URL("../testdata/", import.meta.url)) };

export default defineConfig({
  // Fixtures imported with `?inline` load the same on Node and in browsers.
  assetsInclude: ["**/*.nzd", "**/*.tar.gz"],
  resolve: { alias: [...coreAliases, testDataAlias] },
  test: {
    include: ["test/**/*.test.ts"],
    setupFiles: ["./test/setup.ts"],
    projects: [
      {
        extends: true,
        test: {
          name: "node",
          environment: "node",
          provide: { longImplementation: "bigint" },
        },
      },
      {
        extends: true,
        plugins: [longJsOnlyPlugin],
        test: {
          name: "node-longjs",
          environment: "node",
          exclude: ownBuilds,
          provide: { longImplementation: "long.js" },
        },
      },
      {
        extends: true,
        test: {
          name: "browser",
          exclude: nodeOnly,
          browser: {
            enabled: true,
            provider: playwright(),
            headless: true,
            screenshotFailures: false,
            // Busy CI machines can take over the 60 s default to load a test file's page.
            connectTimeout: 300_000,
            instances: [
              { browser: "chromium", name: "chromium" },
              { browser: "firefox", name: "firefox" },
              // Parallel pages intermittently hang WebKit.
              { browser: "webkit", name: "webkit", maxWorkers: 1 },
              ...(extraBrowsers.has("edge")
                ? [{ browser: "chromium", name: "edge", provider: playwright({ launchOptions: { channel: "msedge" } }) } as const]
                : []),
            ],
          },
        },
      },
      ...(await webdriverProject()),
    ],
    // v8 coverage from the node project only.
    coverage: {
      provider: "custom",
      customProviderModule: "./test/vitest/v8-node-only-coverage.ts",
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.generated.ts", "src/*/dist/**"],
      reporter: ["text-summary", "json-summary", "json"],
      reportsDirectory: "coverage",
      reportOnFailure: true,
    },
  },
});
