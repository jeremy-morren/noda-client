// Empties the given directories (tsc never deletes stale outputs).
// Usage: node ts/scripts/build/clean.ts <dir>...   (repo-relative)
import { mkdirSync } from "node:fs";
import { program, remove, resolvePath } from "noda-scripts/ci";

program.description("Empties directories.").argument("<dirs...>", "repo-relative directories").parse();
for (const dir of program.processedArgs[0] as string[]) {
  remove(dir);
  mkdirSync(resolvePath(dir), { recursive: true });
}
