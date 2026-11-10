// Creates the draft release for a tag at this commit with every package of both ports attached (built by
// ts/scripts/release/pack.ts, build:module, build:native and dart/scripts/package/pack.ts).
// Usage: node scripts/release/create-draft-release.ts --tag v3.3.1 --notes-file <file> [--dry-run]
import { git, glob, program, resolvePath } from "noda-scripts/ci";
import { createDraftRelease } from "noda-scripts/gh";

const { tag, notesFile, dryRun } = program
  .description("Creates the draft release with both ports' packages attached.")
  .requiredOption("--tag <tag>", "the release tag")
  .requiredOption("--notes-file <file>", "the release notes (Markdown), before GitHub's generated ones")
  .option("--dry-run", "only show the assets")
  .parse().opts<{ tag: string; notesFile: string; dryRun?: boolean }>();

const assets: [string, string][] = [
  ["ts/artifacts", "*.tgz"],
  ["ts/artifacts", "*.pdb"],
  ["ts/artifacts", "noda-js-module-*.{zip,tar.gz}"],
  ["artifacts", "noda_dart-*.tar.gz"],
];
const files = assets.flatMap(([dir, pattern]) => glob(dir, pattern).map((f) => resolvePath(`${dir}/${f}`)));
const target = process.env["GITHUB_SHA"] || await git().revparse(["HEAD"]);
console.log(`${dryRun ? "Would create" : "Creating"} the draft release ${tag} at ${target}:\n${files.join("\n")}`);
if (!dryRun) createDraftRelease(tag, target, notesFile, files);
