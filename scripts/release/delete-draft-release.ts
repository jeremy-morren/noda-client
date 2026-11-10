// Deletes the draft release for a tag, and the tag if it's left over (no published release).
// Usage: node scripts/release/delete-draft-release.ts --tag v3.3.1
import { program } from "noda-scripts/ci";
import { deleteRelease, deleteTag, releases, tagExists } from "noda-scripts/gh";

const { tag } = program
  .description("Deletes the draft release for a tag and the leftover tag.")
  .requiredOption("--tag <tag>", "the release tag")
  .parse().opts<{ tag: string }>();

const drafts = releases().filter((r) => r.isDraft && r.tagName === tag);
if (drafts.length > 0) {
  console.log(`Deleting the draft release ${tag}`);
  deleteRelease(tag);
}
if (tagExists(tag)) {
  console.log(`Deleting the leftover tag ${tag}`);
  deleteTag(tag);
}
console.log(`Draft releases for ${tag}: ${drafts.length}.`);
