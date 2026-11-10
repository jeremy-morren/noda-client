// Checks that two clean builds pack byte-identical npm tarballs.
// Usage: npm run check:reproducible
import { rmSync } from "node:fs";
import path from "node:path";
import { fail, glob, program, remove, run, sha256, tempDir } from "noda-scripts/ci";

program.description("Checks that two clean builds pack identical tarballs.").parse();

/** Builds from clean and packs; returns the tarballs' names and hashes. */
function buildAndPack(): string {
  remove("ts/src/noda-js/dist");
  remove("ts/src/noda-js-zod/dist");
  run("npm", ["run", "build", "--silent"], { cwd: "ts" });
  const out = tempDir("noda-js-reproducible-");
  try {
    run("npm", ["pack", "--workspaces", "--silent", "--pack-destination", out], { cwd: "ts" });
    return glob(out, "*.tgz").map((f) => `${f}: ${sha256(path.join(out, f))}`).join("\n");
  } finally {
    rmSync(out, { recursive: true, force: true });
  }
}

const [first, second] = [buildAndPack(), buildAndPack()];
console.log(`${first}\n${second}`);
if (!first || first !== second) fail("Not reproducible: two clean builds packed different tarballs.");
console.log("Reproducible: both clean builds packed the same tarballs.");
