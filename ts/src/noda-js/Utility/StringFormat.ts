// noda-js: new code. string.Format(CultureInfo.InvariantCulture, format, args).

import { PadEnd, PadStart } from "./StringPadding.ts";
import { NewFormatException } from "./SystemExceptions.ts";

/** Formats a .NET composite format string (alignment honoured, format component ignored). @internal */
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
        throw NewFormatException(`Invalid format string: ${format}`);
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
