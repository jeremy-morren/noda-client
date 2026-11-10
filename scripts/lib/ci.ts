// Helpers for the repository's scripts (npm ci at the repository root installs their packages). Paths are relative to
// the repository root; only temp paths (tempPath, tempDir) may be absolute.
import * as core from "@actions/core";
import * as tc from "@actions/tool-cache";
import { execa, execaSync } from "execa";
import type { Options, ResultPromise } from "execa";
import { createHash } from "node:crypto";
import { cpSync, existsSync, globSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import semver from "semver";
import { simpleGit } from "simple-git";
import type { SimpleGit } from "simple-git";

export { default as pRetry, AbortError } from "p-retry";
export { Argument, Option, program } from "commander";
export { core, semver, tc };

export const isWindows = process.platform === "win32";

/** The repository's git. */
export function git(): SimpleGit {
  return simpleGit(import.meta.dirname);
}

/** The repository root (for scripts/lib only: scripts use repo-relative paths). */
export const repoRoot = path.resolve(await git().revparse(["--show-toplevel"]));

/** A path in the CI's temp directory (GitHub Actions' RUNNER_TEMP, Azure DevOps' AGENT_TEMPDIRECTORY), else the OS's. */
export function tempPath(...segments: string[]): string {
  return path.join(process.env["RUNNER_TEMP"] || process.env["AGENT_TEMPDIRECTORY"] || os.tmpdir(), ...segments);
}

/** A new, empty temp directory. */
export function tempDir(prefix: string): string {
  mkdirSync(tempPath(), { recursive: true });
  return mkdtempSync(tempPath(prefix));
}

/** The absolute path of a repo-relative path (or a temp path), for external tools. */
export function resolvePath(relative: string): string {
  if (!path.isAbsolute(relative)) {
    return path.join(repoRoot, relative);
  }
  const inTemp = path.relative(tempPath(), relative);
  if (!inTemp.startsWith("..") && !path.isAbsolute(inTemp)) {
    return relative;
  }
  throw new Error(`Expected a path relative to the repository root, not ${relative}.`);
}

/** Reads a text file. */
export function readFile(file: string): string {
  return readFileSync(resolvePath(file), "utf8");
}

/** Reads a JSON file. */
export function readJson<T = any>(file: string): T {
  return JSON.parse(readFile(file)) as T;
}

/** Writes a file, creating its directory. */
export function writeFile(file: string, data: string | Buffer): void {
  mkdirSync(path.dirname(resolvePath(file)), { recursive: true });
  writeFileSync(resolvePath(file), data);
}

/** Deletes a file or directory tree (nothing if it isn't there). */
export function remove(file: string): void {
  rmSync(resolvePath(file), { recursive: true, force: true });
}

/** Files (not directories) matching a glob pattern in a directory, relative to it. */
export function glob(dir: string, pattern: string): string[] {
  return globSync(pattern, { cwd: resolvePath(dir), withFileTypes: true }).filter((e) => e.isFile())
    .map((e) => path.relative(resolvePath(dir), path.join(e.parentPath, e.name)).replaceAll("\\", "/")).sort();
}

/** Copies a file or directory tree (not node_modules), creating the target's directory. */
export function copy(source: string, target: string): void {
  cpSync(resolvePath(source), resolvePath(target), { recursive: true, filter: (f) => path.basename(f) !== "node_modules" });
}

/** The SHA-256 of a file or bytes, in hex. */
export function sha256(file: string | Buffer): string {
  return createHash("sha256").update(typeof file === "string" ? readFileSync(resolvePath(file)) : file).digest("hex");
}

/** How run, capture and runBin run a command. */
export interface RunOptions {
  /** The working directory (default: the repository root). */
  cwd?: string;
  /** Added to the environment; undefined removes a variable. */
  env?: Record<string, string | undefined>;
  /** Throw on a non-zero exit (default true). */
  check?: boolean;
}

/** Runs a command with inherited stdio; returns its exit code. */
export function run(command: string, args: readonly string[] = [], options: RunOptions = {}): number {
  const result = execaSync(command, args, {
    cwd: resolvePath(options.cwd ?? "."), env: options.env ?? {}, stdio: "inherit", reject: options.check !== false,
  });
  return result.exitCode ?? 1;
}

/** Runs a command and returns its stdout (throws on failure). */
export function capture(command: string, args: readonly string[] = [], options: RunOptions = {}): string {
  return execaSync(command, args, { cwd: resolvePath(options.cwd ?? "."), env: options.env ?? {}, stderr: "inherit" }).stdout;
}

/** Starts a command without waiting (execa; cwd as in run). */
export function start<O extends Options>(command: string, args: readonly string[], options: O & { cwd?: string }): ResultPromise<O> {
  return execa(command, args, { ...options, cwd: resolvePath(options.cwd ?? ".") }) as unknown as ResultPromise<O>;
}

/** Runs a script of this repository with this Node. */
export function runScript(script: string, args: readonly string[] = [], options: RunOptions = {}): number {
  return run(process.execPath, [resolvePath(script), ...args], options);
}

/** Runs an npm package's bin installed in ts/ (default cwd: ts). */
export function runBin(bin: string, args: readonly string[], options: RunOptions = {}): number {
  return run(resolvePath(`ts/node_modules/.bin/${bin}`), args, { cwd: "ts", ...options });
}

/** Sets a GitHub Actions step output (and prints it). */
export function setOutput(name: string, value: string): void {
  console.log(`${name}=${value}`);
  core.setOutput(name, value);
}

/** Sets an environment variable for later GitHub Actions steps and this process (and prints it). */
export function setEnv(name: string, value: string): void {
  console.log(`${name}=${value}`);
  core.exportVariable(name, value);
}

/** Fails the script, with an error annotation in GitHub Actions. */
export function fail(message: string): never {
  core.error(message);
  throw new Error(message);
}

/** Returns a release version (MAJOR.MINOR.PATCH, no prerelease), else fails. */
export function checkVersion(version: string): string {
  if (semver.valid(version) !== version || semver.prerelease(version)) {
    fail(`Release versions are MAJOR.MINOR.PATCH, not '${version}'.`);
  }
  return version;
}

/** version.txt's MAJOR.MINOR (e.g. "3.3"). */
export function majorMinor(): string {
  const text = readFile("version.txt").trim();
  if (!semver.valid(`${text}.0`)) {
    fail(`version.txt must be MAJOR.MINOR (e.g. 3.3), not '${text}'.`);
  }
  return text;
}

/** HEAD's commit time (ISO 8601). */
export async function commitTime(): Promise<string> {
  return (await git().log({ maxCount: 1, format: { date: "%cI" } })).latest!.date;
}

/** Tracked files under a directory, relative to it. */
export async function trackedFiles(dir: string): Promise<string[]> {
  const files = (await git().raw(["ls-files", "--full-name", "--", resolvePath(dir)])).split("\n").filter(Boolean);
  return files.map((f) => path.posix.relative(dir, f)).sort();
}

/** Runs tools/NodaJs.Package (reproducible zip and tar-gzip); from tools/, for its global.json. */
export function nodaJsPackage(...args: string[]): void {
  run("dotnet", ["run", "--project", "NodaJs.Package/NodaJs.Package.csproj", "-c", "Release", "-v", "q", "--", ...args], { cwd: "tools" });
}

/** Publishes tools/NodaJs.Tools to tools/publish and runs one of its commands on this repository. */
export function nodaJsTools(command: string, ...args: string[]): void {
  run("dotnet", ["publish", "--nologo", "NodaJs.Tools/NodaJs.Tools.csproj", "-c", "Release", "-o", "publish", "-v", "quiet"], { cwd: "tools" });
  run("dotnet", ["publish/NodaJs.Tools.dll", command, "--repo", repoRoot, ...args], { cwd: "tools" });
}

/** Copies a package (or the given files of it) into stageRoot at its repository path; returns the copy. */
export function stage(stageRoot: string, source: string, files?: readonly string[]): string {
  const target = path.join(stageRoot, source);
  for (const file of files ?? ["."]) {
    copy(path.join(source, file), path.join(target, file));
  }
  return target;
}

/** Turns a staged package's changelog's Unreleased section into version's (scripts/changelog/changelog.ts). */
export function releaseChangelog(stageRoot: string, version: string, packageName: string): void {
  runScript("scripts/changelog/changelog.ts", ["release", version, packageName, "--root", stageRoot]);
}

/** A test run's name made safe as a file name. */
export function safeFileName(name: string): string {
  return name.replace(/[^A-Za-z0-9.@+-]+/g, "-").replace(/^-+|-+$/g, "");
}

/** Where a test run happens: "<os>-<arch>" (windows-x64, macos-arm64, ...). */
export function platformLabel(): string {
  const name = isWindows ? "windows" : process.platform === "darwin" ? "macos" : "linux";
  const machine = os.machine().toLowerCase();
  const arch = machine === "x86_64" || machine === "amd64" ? "x64" : machine === "aarch64" ? "arm64" : machine;
  return `${name}-${arch}`;
}

/** Waits ms milliseconds. */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** A pinned download of a binary. */
export interface PinnedAsset {
  /** Where to download the archive (.zip, .tar.gz). */
  url: string;
  /** The archive's SHA-256, in hex. */
  sha256: string;
  /** The executable, relative to the install directory. */
  binary: string;
}

/** Downloads, checks and unpacks a pinned binary into dir (unless there already); exports variable as its path. */
export async function installPinned(name: string, version: string, asset: PinnedAsset, dir: string, variable: string): Promise<void> {
  const binary = resolvePath(path.join(dir, asset.binary));
  const stamp = path.join(dir, "version.txt");
  const expected = `${version} ${asset.sha256}`;
  if (existsSync(resolvePath(stamp)) && readFile(stamp).trim() === expected) {
    console.log(`${name} ${version} is already installed: ${binary}`);
  } else {
    remove(dir);
    console.log(`Downloading ${asset.url}`);
    const archive = await tc.downloadTool(asset.url, tempPath(`${name}-${path.basename(asset.url)}`));
    if (sha256(archive) !== asset.sha256) {
      fail(`${asset.url} has SHA-256 ${sha256(archive)}, not the pinned ${asset.sha256}.`);
    }
    await (archive.endsWith(".zip") ? tc.extractZip(archive, resolvePath(dir)) : tc.extractTar(archive, resolvePath(dir)));
    rmSync(archive);
    writeFile(stamp, expected + "\n");
    console.log(`Installed ${name} ${version}: ${binary}`);
  }
  setEnv(variable, binary);
}
