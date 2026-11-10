// noda-js: new code. The TZ environment variable (docs/Timezones.md).

declare const process: { readonly env?: Readonly<Record<string, string | undefined>> } | undefined;
declare const Deno:
  | {
      readonly env?: { get?: (name: string) => string | undefined };
      readonly permissions?: { querySync?: (descriptor: { name: string; variable?: string }) => { state: string } };
    }
  | undefined;

/** For tests: replaces the host's TZ. */
let replacement: { readonly value: string | undefined } | null = null;

/**
 * For tests: TZ reads as `value` (undefined: unset) until the returned function is called. (Setting process.env.TZ
 * would also change Node's Intl default zone.)
 * @internal
 */
export function ReplaceTZEnvironmentVariable(value: string | undefined): () => void {
  const previous = replacement;
  replacement = { value };
  return () => {
    replacement = previous;
  };
}

/** TZ without a leading ":"; null if it's unset, empty or unreadable. @internal */
export function GetTZEnvironmentVariable(): string | null {
  return Normalize(replacement !== null ? replacement.value : ReadHostTZ());
}

/** The host's TZ environment variable, if it can be read. */
function ReadHostTZ(): string | undefined {
  let value: string | undefined;
  try {
    if (typeof Deno !== "undefined" && Deno !== null && typeof Deno.env?.get === "function") {
      // Only with the permission already granted, so there's never a prompt.
      if (Deno.permissions?.querySync?.({ name: "env", variable: "TZ" }).state !== "granted") {
        return undefined;
      }
      value = Deno.env.get("TZ");
    } else if (typeof process !== "undefined" && process !== null && typeof process.env === "object" && process.env !== null) {
      value = process.env["TZ"];
    }
  } catch {
    return undefined;
  }
  return value;
}

/** A leading ":" removed; null for unset or empty. */
function Normalize(value: string | undefined): string | null {
  if (typeof value !== "string") {
    return null;
  }
  if (value.charAt(0) === ":") {
    value = value.substring(1);
  }
  return value === "" ? null : value;
}
