// noda-js: the `noda-js/system` entry point: the host's time zones (NodaTime's Bcl*). See docs/Timezones.md.

import { DateTimeZoneCache, SystemDateTimeZoneSource } from "../internal.ts";
import type { IDateTimeZoneProvider } from "../internal.ts";

export { SystemDateTimeZone, SystemDateTimeZoneSource, TimeZoneInfo, TimeZoneInfoAdjustmentRule, TimeZoneInfoTransitionTime } from "../internal.ts";
export type { InvalidTimeZoneException } from "../internal.ts";

/** A proxy for the value `factory` creates on first access. */
function Lazy<T extends object>(factory: () => T): T {
  let value: T | undefined;
  const get = (): T => (value ??= factory());
  return new Proxy({} as T, {
    get(_target, property) {
      const target = get();
      const result: unknown = Reflect.get(target, property, target);
      return typeof result === "function" && property !== "constructor" ? (result as (...args: unknown[]) => unknown).bind(target) : result;
    },
    has(_target, property) {
      return Reflect.has(get(), property);
    },
    getPrototypeOf() {
      return Object.getPrototypeOf(get()) as object | null;
    },
  });
}

/** The host system's time zones (NodaTime's `DateTimeZoneProviders.Bcl`), created on first use. */
export const SystemDateTimeZoneProvider: IDateTimeZoneProvider = /*#__PURE__*/ Lazy(() => new DateTimeZoneCache(new SystemDateTimeZoneSource()));
