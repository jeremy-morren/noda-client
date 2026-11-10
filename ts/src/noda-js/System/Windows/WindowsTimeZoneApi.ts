// noda-js: new code. Picks how noda-js/system reads Windows' zones: the native addon, then FFI, else none (Intl).

import type { IWindowsTimeZoneApi } from "./IWindowsTimeZoneApi.ts";
import { FfiWindowsTimeZoneApi } from "./FfiWindowsTimeZoneApi.ts";
import { GetBuiltinModule, GetCurrentDirectory, GetProcessArchitecture, IsWindowsRuntime } from "../Host.ts";

/** Where noda-js/system gets its zones: the native addon package, the runtime's FFI, or the host's Intl. */
export type SystemTimeZoneBackend = "addon" | "ffi" | "intl";

/** A way to read Windows' time zone data. @internal */
export interface WindowsTimeZoneApiBackend {
  readonly Backend: Exclude<SystemTimeZoneBackend, "intl">;
  /** For VersionId: e.g. "node:ffi", or the addon's package name. */
  readonly Description: string;
  readonly Api: IWindowsTimeZoneApi;
}

/** The native addon's package name for this architecture, e.g. "noda-js-win32-x64". @internal */
export function GetAddonPackageName(): string | null {
  const arch = GetProcessArchitecture();
  return arch === "x64" || arch === "arm64" ? `noda-js-win32-${arch}` : null;
}

/** The native addon's API, if its package is installed and loads. */
function TryLoadAddon(): WindowsTimeZoneApiBackend | null {
  const name = GetAddonPackageName();
  if (name === null) {
    return null;
  }
  try {
    const module = GetBuiltinModule("module") as { createRequire?: (path: string) => (id: string) => unknown } | undefined;
    if (module === undefined || module === null || typeof module.createRequire !== "function") {
      return null;
    }
    // esbuild empties import.meta in the ES2015 single-file module: resolve from the current directory there.
    // eslint-disable-next-line es-x/no-import-meta -- ES module output; only reached on Node, Bun and Deno
    const moduleUrl = (import.meta as { readonly url?: string }).url;
    const cwd = GetCurrentDirectory();
    const base = moduleUrl ?? (cwd === undefined ? undefined : `${cwd}\\`);
    if (base === undefined) {
      return null;
    }
    const require = module.createRequire(base);
    const addon = require(name) as Partial<IWindowsTimeZoneApi> | null;
    if (addon === null || typeof addon !== "object" || typeof addon.GetDynamicTimeZoneInformation !== "function") {
      return null;
    }
    return { Backend: "addon", Description: name, Api: addon as IWindowsTimeZoneApi };
  } catch {
    return null;
  }
}

function TryLoadFfi(): WindowsTimeZoneApiBackend | null {
  const api = FfiWindowsTimeZoneApi.TryCreate();
  return api === null ? null : { Backend: "ffi", Description: api.FfiName, Api: api };
}

/** The native addon, else FFI; null if this isn't a Windows runtime or neither is available. @internal */
export function FindWindowsTimeZoneApi(): WindowsTimeZoneApiBackend | null {
  if (!IsWindowsRuntime()) {
    return null;
  }
  return TryLoadAddon() ?? TryLoadFfi();
}
