// The packages' changelogs (Keep a Changelog format, via keep-a-changelog): release notes, releasing, format check.
// Usage: node scripts/changelog/changelog.ts notes | release <version> [package] [--root <dir>] | check [--fix]
import { type Changelog, parser, Release } from "keep-a-changelog";
import path from "node:path";
import { Argument, checkVersion, commitTime, fail, program, readFile, writeFile } from "noda-scripts/ci";

const changelogs: Record<string, string> = {
  "noda-js": "ts/src/noda-js/CHANGELOG.md",
  "noda_dart": "dart/noda_dart/CHANGELOG.md",
};
// Version links compare the tags vMAJOR.MINOR.PATCH.
const url = "https://github.com/jeremy-morren/noda-client";

/** Parses a package's changelog (under dir: the repository, or a staged copy laid out like it). */
function read(name: string, dir = ""): Changelog {
  const changelog = parser(readFile(path.join(dir, changelogs[name]!)));
  changelog.url = url;
  return changelog;
}

program.description("The packages' changelogs.");

program.command("notes")
  .description("prints the draft release's notes: each package's Unreleased section")
  .action(() => {
    const sections = Object.keys(changelogs).map((name) => {
      // The release's Markdown without its "## [Unreleased]" heading.
      const body = read(name).findRelease()?.toString().split("\n").slice(1).join("\n").trim();
      return `## ${name}\n\n${body ? body.replace(/^### /gm, "#### ") : "No changes."}`;
    });
    process.stdout.write(sections.join("\n\n") + "\n");
  });

program.command("release")
  .description("turns the Unreleased sections into <version>'s, dated by HEAD's commit")
  .argument("<version>", "the release version", checkVersion)
  .addArgument(new Argument("[package]", "one package (default: both)").choices(Object.keys(changelogs)))
  .option("--root <dir>", "a staged copy laid out like the repository (default: the repository)", "")
  .action(async (version: string, packageName: string | undefined, { root }: { root: string }) => {
    // HEAD's commit date, so every build of a commit writes the same file.
    const date = (await commitTime()).substring(0, 10);
    for (const name of packageName ? [packageName] : Object.keys(changelogs)) {
      const changelog = read(name, root);
      if (changelog.findRelease(version)) {
        console.log(`${changelogs[name]} already has ${version}.`);
        continue;
      }
      const unreleased = changelog.findRelease() ?? changelog.addRelease(new Release()).findRelease()!;
      unreleased.setVersion(version);
      unreleased.setDate(new Date(date));
      changelog.addRelease(new Release());
      writeFile(path.join(root, changelogs[name]!), changelog.toString());
      console.log(`${changelogs[name]}: ${version} (${date}).`);
    }
  });

program.command("check")
  .description("checks each changelog is in keep-a-changelog's format")
  .option("--fix", "reformat instead")
  .action(({ fix }: { fix?: boolean }) => {
    for (const [name, file] of Object.entries(changelogs)) {
      const formatted = read(name).toString();
      if (readFile(file) === formatted) continue;
      if (!fix) fail(`${file} isn't in keep-a-changelog's format: run node scripts/changelog/changelog.ts check --fix`);
      writeFile(file, formatted);
      console.log(`Formatted ${file}.`);
    }
  });

await program.parseAsync();
