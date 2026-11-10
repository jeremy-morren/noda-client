// Builds the Windows native addon into ts/src/noda-js-win-<arch>/time-zones.node and, when it can run here, checks
// it against noda-js's node:ffi implementation (compare-native.ts). Needs Visual Studio's C++ tools and its C++ Clang
// tools for Windows (clang-cl, lld-link). Windows only.
// Usage: npm run build:native [-- --arch x64|arm64]
import { copy, Option, platformLabel, program, runBin, runScript, sha256 } from "noda-scripts/ci";

const { arch } = program
  .description("Builds the Windows native addon (Windows only).")
  .addOption(new Option("--arch <arch>", "the target architecture").choices(["x64", "arm64"]).default(platformLabel().split("-")[1]))
  .parse().opts<{ arch: string }>();
const addon = `ts/src/noda-js-win-${arch}/time-zones.node`;
runBin("node-gyp", ["rebuild", `--arch=${arch}`], { cwd: "ts/native/windows" });
copy("ts/native/windows/build/Release/time-zones.node", addon);
console.log(`Built ${addon} (${sha256(addon)}); its PDB (not packed): ts/native/windows/build/Release/time-zones.pdb`);

if (process.arch === arch) {
  // compare-native.ts imports noda-js's built output.
  runBin("tsc", ["-b", "src/noda-js"]);
  runScript("ts/scripts/native/compare-native.ts", [addon]);
} else {
  console.log(`Skipped the comparison with node:ffi (an ${arch} addon can't run on this ${process.arch} Node).`);
}
