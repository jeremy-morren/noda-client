// noda-js: equivalent of string.Format(CultureInfo.InvariantCulture, format, args) for the
// composite format strings NodaTime uses ("{0}", "{1}", "{{" and "}}").

import { PadEnd, PadStart } from "./StringPadding.ts";

/**
 * Formats a .NET composite format string. Arguments are converted with String(); an alignment
 * component ("{0,5}") is honoured, and a format component ("{0:x}") is ignored.
 * @internal
 */
export function FormatString(format: string, ...args: unknown[]): string {
  let result = "";
  for (let i = 0; i < format.length; i++) {
    const ch = format[i]!;
    if (ch === "{") {
      if (format[i + 1] === "{") {
        result += "{";
        i++;
        continue;
      }
      const end = format.indexOf("}", i);
      if (end === -1) {
        throw new Error(`Invalid format string: ${format}`);
      }
      const spec = format.substring(i + 1, end);
      const indexAndAlignment = spec.split(":", 1)[0]!;
      const [indexText, alignmentText] = indexAndAlignment.split(",");
      const arg = args[Number(indexText)];
      let text = arg === null || arg === undefined ? "" : String(arg);
      if (alignmentText !== undefined) {
        const alignment = Number(alignmentText);
        text = alignment >= 0 ? PadStart(text, alignment) : PadEnd(text, -alignment);
      }
      result += text;
      i = end;
    } else if (ch === "}") {
      if (format[i + 1] === "}") {
        i++;
      }
      result += "}";
    } else {
      result += ch;
    }
  }
  return result;
}
