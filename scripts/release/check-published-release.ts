// Fails unless a tag's release is published (not a draft).
// Usage: node scripts/release/check-published-release.ts --tag v3.3.1
import { fail, program } from "noda-scripts/ci";
import { isDraft } from "noda-scripts/gh";

const { tag } = program
  .description("Fails unless the tag's release is published.")
  .requiredOption("--tag <tag>", "the release tag")
  .parse().opts<{ tag: string }>();
if (isDraft(tag)) fail(`${tag} isn't a published release.`);
console.log(`${tag} is a published release.`);
