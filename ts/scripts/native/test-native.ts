// Builds and runs the native addon's C tests (ts/native/windows/test/) with Visual Studio's clang-cl and lld-link, for
// this machine's architecture; --coverage also measures their coverage (LLVM source-based coverage, with the same
// LLVM's llvm-profdata and llvm-cov). Needs Visual Studio's C++ tools and its C++ Clang tools for Windows. Windows only.
// Usage: npm run test:native [-- --coverage]
import { mkdirSync } from "node:fs";
import path from "node:path";
import { capture, fail, program, resolvePath, run, writeFile } from "noda-scripts/ci";

const { coverage } = program
  .description("Builds and runs the native addon's C tests (Windows only).")
  .option("--coverage", "measure line and branch coverage into ts/test-results/native-coverage.lcov")
  .parse().opts<{ coverage?: boolean }>();

const source = "ts/native/windows";
const exe = `${source}/build/test/windows-time-zones.test.exe`;
const profile = `${source}/build/test/windows-time-zones.test`;
const report = "ts/test-results/native-coverage.lcov";

/** The bin directory of the latest Visual Studio's LLVM (C++ Clang tools for Windows), for this machine. */
function llvmBin(): string {
  const vswhere = path.join(process.env["ProgramFiles(x86)"]!, "Microsoft Visual Studio", "Installer", "vswhere.exe");
  const component = "Microsoft.VisualStudio.Component.VC.Llvm.Clang";
  const vs = capture(vswhere, ["-latest", "-products", "*", "-requires", component, "-property", "installationPath"]).trim()
    || fail(`No Visual Studio with ${component}.`);
  return path.join(vs, "VC", "Tools", "Llvm", process.arch === "arm64" ? "ARM64" : "x64", "bin");
}

const llvm = llvmBin();
mkdirSync(resolvePath(`${source}/build/test`), { recursive: true });
// clang-cl finds Visual Studio's C runtime and the Windows SDK itself (no developer shell).
run(path.join(llvm, "clang-cl.exe"), [
  "/nologo", "/W4", "/WX", "/utf-8", "/Z7", "/Od", "-fuse-ld=lld",
  ...(coverage ? ["-fprofile-instr-generate", "-fcoverage-mapping"] : []),
  "/Fobuild\\test\\", "/Febuild\\test\\windows-time-zones.test.exe", "test\\windows-time-zones.test.c", "windows-time-zones.c",
  "/link", "/DEBUG:FULL", "/INCREMENTAL:NO", "advapi32.lib", "user32.lib",
], { cwd: source });
run(resolvePath(exe), ["-v"], { env: { LLVM_PROFILE_FILE: resolvePath(`${profile}.profraw`) } });

if (coverage) {
  run(path.join(llvm, "llvm-profdata.exe"), ["merge", "-sparse", `${profile}.profraw`, "-o", `${profile}.profdata`]);
  const files = [`${source}/windows-time-zones.c`, `${source}/test/windows-time-zones.test.c`].map(resolvePath);
  const args = [resolvePath(exe), `-instr-profile=${resolvePath(`${profile}.profdata`)}`, ...files];
  writeFile(report, capture(path.join(llvm, "llvm-cov.exe"), ["export", "-format=lcov", ...args]));
  const summary = JSON.parse(capture(path.join(llvm, "llvm-cov.exe"), ["export", "-summary-only", ...args]));
  for (const file of summary.data[0].files) {
    const { lines, branches } = file.summary;
    console.log(`${path.basename(file.filename)}: ${lines.percent.toFixed(1)}% of lines, ${branches.percent.toFixed(1)}% of branches (${report})`);
  }
}
