// Pins NodaTime (tools/nodatime-ref.txt) to a commit or tag; default: main's latest commit.
// Usage: node tools/update-nodatime.ts [--ref <sha|tag>]
import { git, program, readFile, writeFile } from "noda-scripts/ci";

const options = program
  .description("Pins the NodaTime the ports follow.")
  .option("--ref <ref>", "a NodaTime commit SHA or tag (default: main's latest commit)")
  .parse().opts<{ ref?: string }>();
const ref = options.ref ?? (await git().listRemote(["https://github.com/nodatime/nodatime.git", "refs/heads/main"])).split(/\s+/)[0]!;

const file = "tools/nodatime-ref.txt";
const current = readFile(file).trim();
writeFile(file, `${ref}\n`);
console.log(current === ref ? `NodaTime is already at ${ref}.` : `NodaTime is now at ${ref}.`);
