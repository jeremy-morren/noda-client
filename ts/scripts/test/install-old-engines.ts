// Installs pinned engines without BigInt (Node 8, QuickJS 2019-12-21, Chromium 66) into node_modules/.cache/old-engines
// for test/module/old-engines.test.ts; engines with no build for this OS and architecture are skipped. Sets
// NODE8_PATH, QUICKJS2019_PATH and CHROMIUM66_PATH in GitHub Actions.
// Usage: npm run test:install-old-engines
import { installPinned, platformLabel, program } from "noda-scripts/ci";
import type { PinnedAsset } from "noda-scripts/ci";

program.description("Installs the pinned engines without BigInt.").parse();
const label = platformLabel();
const linuxX64 = label === "linux-x64";
// Node's SHA-256s are from https://nodejs.org/dist/v8.17.0/SHASUMS256.txt.
const node8: Record<string, PinnedAsset> = {
  "linux-x64": { url: "https://nodejs.org/dist/v8.17.0/node-v8.17.0-linux-x64.tar.gz", sha256: "8b2c9e1f84317c4b02736c4c50db4dd2cd6c4f0ba910fa81f887c8c9294af596", binary: "node-v8.17.0-linux-x64/bin/node" },
  "macos-x64": { url: "https://nodejs.org/dist/v8.17.0/node-v8.17.0-darwin-x64.tar.gz", sha256: "3117430fc93e9865e4a1842616cc98767b5d6987fd9d727c8be4068714570e16", binary: "node-v8.17.0-darwin-x64/bin/node" },
  // Also for Windows on ARM64, which runs it emulated.
  "windows": { url: "https://nodejs.org/dist/v8.17.0/node-v8.17.0-win-x64.zip", sha256: "e95a63e81b27e78872c0efb9dd5809403014dbf9896035cc17adf51a350f88fa", binary: "node-v8.17.0-win-x64/node.exe" },
};

const engines: { name: string; variable: string; version: string; asset: PinnedAsset | undefined }[] = [
  { name: "node8", variable: "NODE8_PATH", version: "v8.17.0", asset: node8[label] ?? node8[label.split("-")[0]!] },
  {
    name: "quickjs", variable: "QUICKJS2019_PATH", version: "2019-12-21",
    asset: linuxX64 ? { url: "https://bellard.org/quickjs/binary_releases/quickjs-linux-x86_64-2019-12-21.zip", sha256: "69c54057fbb127bb7fbb104376c88a689c6d1c30dff181c257fc1d8e025defa8", binary: "qjs" } : undefined,
  },
  {
    name: "chromium", variable: "CHROMIUM66_PATH", version: "66.0.3359.0 (540276)",
    asset: linuxX64 ? { url: "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/540276/chrome-linux.zip", sha256: "1e1a69323c01ef18111199381dd04b5afcde1de9c517cadb3342afffbf46b7bf", binary: "chrome-linux/chrome" } : undefined,
  },
];

for (const engine of engines) {
  if (!engine.asset) {
    console.log(`${engine.name} ${engine.version}: no build for ${label}; skipped.`);
    continue;
  }
  await installPinned(engine.name, engine.version, engine.asset, `ts/node_modules/.cache/old-engines/${engine.name}`, engine.variable);
}
