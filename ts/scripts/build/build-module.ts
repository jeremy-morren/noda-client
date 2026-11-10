// Builds the single-file ES module (ts/artifacts/module) and its reproducible release archives
// ts/artifacts/noda-js-module-<version>.zip and .tar.gz.
// Usage: npm run build:module [-- --version 3.3.1]
import { checkVersion, commitTime, glob, nodaJsPackage, program, readJson, remove, resolvePath, runScript } from "noda-scripts/ci";

const { version } = program
  .description("Builds the single-file ES module and its release archives.")
  .option("--version <version>", "the archives' version (default: noda-js's package.json)", checkVersion,
    readJson("ts/src/noda-js/package.json").version as string)
  .parse().opts<{ version: string }>();
const files = ["noda-js.js", "noda-js.js.map", "--directory", resolvePath("ts/artifacts/module"), "--time", await commitTime()];

runScript("ts/standalone/build.ts", [], { cwd: "ts" });
for (const old of glob("ts/artifacts", "noda-js-module-*")) {
  remove(`ts/artifacts/${old}`);
}
const archive = resolvePath(`ts/artifacts/noda-js-module-${version}`);
nodaJsPackage("zip", `${archive}.zip`, ...files);
nodaJsPackage("tar-gzip", `${archive}.tar.gz`, ...files);
