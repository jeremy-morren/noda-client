// Deletes the draft release for a tag, and the tag if it's left over (no published release).
// Usage: node scripts/release/delete-draft-release.ts --tag v3.3.1 [--dry-run]
import { program } from "noda-scripts/ci";
import { deleteRelease, deleteTag, releases, tagExists } from "noda-scripts/gh";

const { tag, dryRun } = program
  .description("Deletes the draft release for a tag and the leftover tag.")
  .requiredOption("--tag <tag>", "the release tag")
  .option("--dry-run", "only show what would be deleted")
  .parse().opts<{ tag: string; dryRun?: boolean }>();
const action = dryRun ? "Would delete" : "Deleting";

const drafts = releases().filter((r) => r.isDraft && r.tagName === tag);
if (drafts.length > 0) {
  console.log(`${action} the draft release ${tag}`);
  if (!dryRun) deleteRelease(tag);
}
if (tagExists(tag)) {
  console.log(`${action} the leftover tag ${tag}`);
  if (!dryRun) deleteTag(tag);
}
console.log(`Draft releases for ${tag}: ${drafts.length}.`);
