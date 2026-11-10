// The GitHub operations the scripts need, through the gh CLI (it finds the repository and authenticates itself).
import { execaSync } from "execa";
import { repoRoot } from "./ci.ts";

/** Runs gh in the repository root; returns its stdout. */
function gh(...args: string[]): string {
  return execaSync("gh", args, { cwd: repoRoot, stderr: "inherit" }).stdout;
}

/** The repository's releases, drafts included. */
export function releases(): { tagName: string; isDraft: boolean }[] {
  return JSON.parse(gh("release", "list", "--limit", "1000", "--json", "tagName,isDraft"));
}

/** Deletes a release and its tag. */
export function deleteRelease(tag: string): void {
  gh("release", "delete", tag, "--cleanup-tag", "--yes");
}

/** Whether the tag exists on GitHub. */
export function tagExists(tag: string): boolean {
  return execaSync("gh", ["api", `repos/{owner}/{repo}/git/ref/tags/${tag}`], { cwd: repoRoot, reject: false }).exitCode === 0;
}

/** Deletes a tag on GitHub. */
export function deleteTag(tag: string): void {
  gh("api", "-X", "DELETE", `repos/{owner}/{repo}/git/refs/tags/${tag}`);
}

/** Downloads a release's assets matching pattern into dir. */
export function downloadReleaseAssets(tag: string, pattern: string, dir: string): void {
  gh("release", "download", tag, "--pattern", pattern, "--dir", dir);
}

/** Whether a tag's release is a draft (throws if there's no release). */
export function isDraft(tag: string): boolean {
  return (JSON.parse(gh("release", "view", tag, "--json", "isDraft")) as { isDraft: boolean }).isDraft;
}

/** Creates a draft release of target with files attached, its notes from notesFile followed by GitHub's generated ones. */
export function createDraftRelease(tag: string, target: string, notesFile: string, files: readonly string[]): void {
  gh("release", "create", tag, ...files, "--draft", "--target", target, "--title", tag, "--notes-file", notesFile, "--generate-notes");
}

/** Creates or updates a label. */
export function createLabel(name: string, description: string): void {
  gh("label", "create", name, "--description", description, "--force");
}

/** The open pull request from a branch, if any. */
export function openPullRequest(branch: string): number | undefined {
  return (JSON.parse(gh("pr", "list", "--head", branch, "--state", "open", "--json", "number")) as { number: number }[])[0]?.number;
}

/** Opens a pull request from a branch to main. */
export function createPullRequest(branch: string, title: string, body: string, label: string): void {
  gh("pr", "create", "--base", "main", "--head", branch, "--label", label, "--title", title, "--body", body);
}

/** Comments on a pull request. */
export function commentPullRequest(pr: number, body: string): void {
  gh("pr", "comment", String(pr), "--body", body);
}
