// noda-js: new code. Host feature detection for noda-js/system (no static imports of host modules).

// The build has no Node, Bun or Deno types.
declare const process:
  | {
      readonly platform?: string;
      readonly arch?: string;
      readonly versions?: { readonly node?: unknown; readonly bun?: unknown };
      readonly getBuiltinModule?: (id: string) => unknown;
      readonly cwd?: () => string;
    }
  | undefined;
declare const Deno: { readonly build?: { readonly os?: string } } | undefined;

/** Whether this is Node, Bun or Deno on Windows (never a browser, nor a bundler's `process` shim). @internal */
export function IsWindowsRuntime(): boolean {
  if (typeof Deno !== "undefined" && typeof Deno?.build?.os === "string") {
    return Deno.build.os === "windows";
  }
  if (typeof process === "undefined" || process === null || process.platform !== "win32") {
    return false;
  }
  const versions = process.versions;
  return versions !== undefined && (typeof versions.node === "string" || typeof versions.bun === "string");
}

/** process.getBuiltinModule(id) where the host has it, else undefined. @internal */
export function GetBuiltinModule(id: string): unknown {
  if (typeof process === "undefined" || process === null || typeof process.getBuiltinModule !== "function") {
    return undefined;
  }
  return process.getBuiltinModule(id);
}

/** process.cwd(), or undefined. @internal */
export function GetCurrentDirectory(): string | undefined {
  return typeof process === "undefined" || process === null || typeof process.cwd !== "function" ? undefined : process.cwd();
}

/** process.arch ("x64", "arm64", ...), or undefined. @internal */
export function GetProcessArchitecture(): string | undefined {
  return typeof process === "undefined" || process === null ? undefined : process.arch;
}
