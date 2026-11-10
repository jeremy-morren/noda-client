// Adds a Markdown file to the GitHub Actions job summary.
// Usage: node scripts/ci/step-summary.ts <file.md>
import { core, program, readFile } from "noda-scripts/ci";

program
  .description("Adds a Markdown file to the job summary.")
  .argument("<file>", "the repo-relative Markdown file")
  .parse();
const [file] = program.processedArgs as [string];
await core.summary.addRaw(readFile(file), true).write();
