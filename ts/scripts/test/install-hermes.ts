// Installs the pinned Hermes CLI (v0.13.0, the last release with prebuilt binaries) into node_modules/.cache/hermes
// for test/module/hermes.test.ts; sets HERMES_PATH in GitHub Actions.
// Usage: npm run test:install-hermes
import { fail, installPinned, platformLabel, program } from "noda-scripts/ci";

program.description("Installs the pinned Hermes CLI.").parse();
const version = "v0.13.0";
// SHA-256s of https://github.com/facebook/hermes/releases/tag/v0.13.0's assets.
const assets = {
  windows: { name: "hermes-cli-windows.tar.gz", sha256: "485907ae87f267f7901f45c12979fea9703967ee2fa930bab887d022de9d6478", binary: "hermes.exe" },
  macos: { name: "hermes-cli-darwin.tar.gz", sha256: "f16b0214f7b96eccbd47766f5a3914e847a4387649b2f6b60820d309879200bd", binary: "hermes" },
  linux: { name: "hermes-cli-linux.tar.gz", sha256: "aead6eb0b8f563bb022354352eae32dad96c933330b6c1941b6db17674ca68ae", binary: "hermes" },
};

const [os, arch] = platformLabel().split("-") as [keyof typeof assets, string];
// Windows on ARM64 runs the x64 build emulated.
if (os === "linux" && arch !== "x64") fail(`Hermes ${version} has Linux binaries for x64 only, not ${arch}.`);
const asset = assets[os];
await installPinned("Hermes", version, {
  url: `https://github.com/facebook/hermes/releases/download/${version}/${asset.name}`,
  sha256: asset.sha256,
  binary: asset.binary,
}, "ts/node_modules/.cache/hermes", "HERMES_PATH");
