// Commits the changelogs as released (changelog.ts release) to the branch changelog-update-<tag> and opens a pull
// request to main labelled "release changelog" (changelog-only, so no CI), or comments on the open one.
// Usage: node scripts/release/changelog-pull-request.ts --tag v3.3.1
import { git, program } from "noda-scripts/ci";
import { commentPullRequest, createLabel, createPullRequest, openPullRequest } from "noda-scripts/gh";

const { tag } = program
  .description("Opens the pull request with the released changelogs.")
  .requiredOption("--tag <tag>", "the release tag")
  .parse().opts<{ tag: string }>();
const branch = `changelog-update-${tag}`;
const label = "release changelog";
const title = `Changelog update - ${tag}`;
const repo = git();

if (!(await repo.diff())) {
  console.log(`The changelogs already have ${tag}.`);
} else {
  await repo.addConfig("user.email", "action@github.com").addConfig("user.name", "GitHub Action");
  await repo.checkout(["-B", branch]);
  await repo.commit(title, undefined, { "--all": null });
  await repo.push(["--force", "--set-upstream", "origin", branch]);
  createLabel(label, "Pull requests with release changelog update");
  const existing = openPullRequest(branch);
  if (existing === undefined) {
    createPullRequest(branch, title, `The changelogs as released in ${tag}.`, label);
  } else {
    commentPullRequest(existing, "Updated the changelogs after a re-run.");
  }
  console.log(`${branch}: ${existing === undefined ? "opened a pull request" : `updated #${existing}`}.`);
}
