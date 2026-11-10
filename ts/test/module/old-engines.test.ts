// The workload in the single-file module on engines without BigInt (Node 8.17, QuickJS 2019-12-21, Chromium 66;
// npm run test:install-old-engines): must match src/, using long.js. Built as a classic script (no ES modules there).

import { beforeAll, describe, expect, it } from "vitest";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { build } from "esbuild";
import { moduleBuildOptions } from "../../standalone/build.ts";
import { literalWorkload, runWorkload, workloadSource } from "../helpers/workload.ts";
import * as core from "../../src/noda-js/index.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { esES } from "../../src/noda-js/Cultures/index.generated.ts";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const cache = path.join(root, "node_modules/.cache/old-engines");

function engine(variable: string, installed: string): { binary: string; available: boolean } {
  const fromEnv = process.env[variable];
  if (fromEnv) {
    return { binary: fromEnv, available: true };
  }
  const binary = path.join(cache, installed);
  return { binary, available: existsSync(binary) };
}

const node8 = engine("NODE8_PATH", process.platform === "win32" ? "node8/node-v8.17.0-win-x64/node.exe"
  : `node8/node-v8.17.0-${process.platform === "darwin" ? "darwin" : "linux"}-x64/bin/node`);
const quickjs = engine("QUICKJS2019_PATH", "quickjs/qjs");
const chromium = engine("CHROMIUM66_PATH", "chromium/chrome-linux/chrome");

const run = promisify(execFile);
let dir: string;
let moduleScript: string;
const workloadCall = `var __results = (${workloadSource})(NodaJs);\n`;

beforeAll(async () => {
  dir = await mkdtemp(path.join(tmpdir(), "noda-js-old-engines-"));
  const result = await build({ ...moduleBuildOptions("out"), format: "iife", globalName: "NodaJs", write: false, sourcemap: false });
  moduleScript = result.outputFiles!.find((f) => f.path.endsWith("noda-js.js"))!.text;
  return () => rm(dir, { recursive: true, force: true });
}, 120_000);

function expected(): Record<string, string> {
  const results = runWorkload({ ...core, tzdb, esES });
  delete results.long;
  return results;
}

function check(results: Record<string, string>): void {
  expect(results.long, "the 64-bit integer noda-js picked").toBe("long.js");
  const { long: _, ...rest } = results;
  expect(rest).toEqual(expected());
  for (const [name, value] of Object.entries(literalWorkload)) {
    expect(results[name], name).toBe(value);
  }
}

describe.skipIf(!node8.available)("noda-js.js on Node.js 8.17.0 (no BigInt)", () => {
  it("picks long.js and gives exactly src/'s results", async () => {
    const file = path.join(dir, "node8.js");
    await writeFile(file, `${moduleScript}\n${workloadCall}console.log(JSON.stringify(__results));\n`);
    const { stdout } = await run(node8.binary, [file], { maxBuffer: 16 * 1024 * 1024 });
    check(JSON.parse(stdout.trim()) as Record<string, string>);
    const { stdout: version } = await run(node8.binary, ["-p", "process.version + ' ' + typeof BigInt"]);
    expect(version.trim()).toBe("v8.17.0 undefined");
  }, 120_000);
});

describe.skipIf(!quickjs.available)("noda-js.js in QuickJS 2019-12-21 (no BigInt)", () => {
  it("picks long.js and gives exactly src/'s results", async () => {
    const file = path.join(dir, "quickjs.js");
    await writeFile(file, `${moduleScript}\n${workloadCall}print(typeof BigInt);\nprint(JSON.stringify(__results));\n`);
    const { stdout } = await run(quickjs.binary, [file], { maxBuffer: 16 * 1024 * 1024 });
    const [bigint, json] = stdout.trim().split("\n");
    expect(bigint).toBe("undefined");
    check(JSON.parse(json!) as Record<string, string>);
  }, 120_000);
});

describe.skipIf(!chromium.available)("noda-js.js in Chromium 66 (no BigInt)", () => {
  it("picks long.js and gives exactly src/'s results", async () => {
    // URI-encoded, so --dump-dom doesn't escape them.
    await writeFile(path.join(dir, "noda-js.js"), moduleScript);
    const page = path.join(dir, "page.html");
    await writeFile(page, `<!DOCTYPE html><html><body><pre id="out">pending</pre><script src="noda-js.js"></script><script>
try {
  ${workloadCall}
  __results.bigint = typeof BigInt;
  __results.userAgent = navigator.userAgent;
  document.getElementById("out").textContent = encodeURIComponent(JSON.stringify(__results));
} catch (e) {
  document.getElementById("out").textContent = encodeURIComponent("failed: " + e);
}
</script></body></html>`);
    const { stdout } = await run(chromium.binary,
      ["--headless", "--disable-gpu", "--no-sandbox", `--user-data-dir=${path.join(dir, "profile")}`, "--dump-dom", pathToFileURL(page).href],
      { maxBuffer: 16 * 1024 * 1024, timeout: 110_000 });
    const out = /<pre id="out">([^<]*)<\/pre>/.exec(stdout)?.[1];
    expect(out, "the page's #out").toBeDefined();
    const text = decodeURIComponent(out!);
    expect(text).not.toMatch(/^(pending|failed)/);
    const { bigint, userAgent, ...results } = JSON.parse(text) as Record<string, string>;
    expect(bigint).toBe("undefined");
    expect(userAgent).toMatch(/HeadlessChrome\/66\./);
    check(results);
  }, 120_000);
});
