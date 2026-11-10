// Stages every packed npm tarball (ts/artifacts/*.tgz) on npm (npm stage publish; live once a maintainer approves it).
// Usage: node ts/scripts/release/stage-npm.ts [--dry-run]
import { glob, program, run } from "noda-scripts/ci";

const { dryRun } = program
  .description("Stages the packed npm tarballs on npm.")
  .option("--dry-run", "only show the tarballs")
  .parse().opts<{ dryRun?: boolean }>();
for (const tarball of glob("ts/artifacts", "*.tgz")) {
  console.log(`${dryRun ? "Would stage" : "Staging"} ${tarball}`);
  if (!dryRun) run("npm", ["stage", "publish", `artifacts/${tarball}`], { cwd: "ts" });
}
