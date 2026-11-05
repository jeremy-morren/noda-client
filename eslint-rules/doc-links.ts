// ESLint rule: every {@link X} / {@linkcode X} / {@linkplain X} in a doc comment must resolve to a declaration, the
// way the TypeScript language service resolves it for hover text and go-to-definition (names in scope, members of the
// enclosing class, qualified names such as {@link Duration.FromDays}). TypeScript itself never reports a link that
// doesn't resolve, so a missing import (e.g. a type mentioned only in docs) or a renamed member goes unnoticed.
// Links to URLs ({@link https://...}) aren't checked.
import type { Rule } from "eslint";
import ts from "typescript";

type Link = ts.JSDocLink | ts.JSDocLinkCode | ts.JSDocLinkPlain;

/** The parts of typescript-eslint's parser services (with type information) this rule uses. */
interface TypeServices {
  program?: ts.Program;
  esTreeNodeToTSNodeMap: { get(node: unknown): ts.Node };
}

const rule: Rule.RuleModule = {
  meta: {
    type: "problem",
    docs: { description: "Require {@link} references in doc comments to resolve" },
    messages: {
      unresolved: "{@link {{name}}} doesn't resolve: import the type (import type is enough) or fix the name.",
    },
    schema: [],
  },
  create(context) {
    const services = context.sourceCode.parserServices as Partial<TypeServices> | undefined;
    if (!services?.program || !services.esTreeNodeToTSNodeMap) {
      throw new Error("doc-links needs type information (parserOptions.projectService).");
    }
    const checker = services.program.getTypeChecker();
    const nodeMap = services.esTreeNodeToTSNodeMap;
    return {
      Program(node) {
        const sourceFile = nodeMap.get(node) as ts.SourceFile;
        // ESLint locations are 1-based lines and 0-based columns; TypeScript's lines are 0-based.
        const location = (position: number) => {
          const { line, character } = sourceFile.getLineAndCharacterOfPosition(position);
          return { line: line + 1, column: character };
        };
        const visitDoc = (doc: ts.Node): void => {
          if (ts.isJSDocLink(doc) || ts.isJSDocLinkCode(doc) || ts.isJSDocLinkPlain(doc)) {
            if (doc.name && !isUrl(doc) && !resolves(checker, doc.name)) {
              context.report({
                loc: { start: location(doc.getStart(sourceFile)), end: location(doc.getEnd()) },
                messageId: "unresolved",
                data: { name: doc.name.getText(sourceFile) },
              });
            }
            return;
          }
          ts.forEachChild(doc, visitDoc);
        };
        const visit = (tsNode: ts.Node): void => {
          // jsDoc is where the parser attaches doc comments; it isn't part of the public node type.
          for (const doc of (tsNode as ts.Node & { jsDoc?: ts.JSDoc[] }).jsDoc ?? []) {
            visitDoc(doc);
          }
          ts.forEachChild(tsNode, visit);
        };
        visit(sourceFile);
      },
    };
  },
};

export default rule;

/** {@link https://example.com} parses as the name "https" followed by "://example.com". */
function isUrl(link: Link): boolean {
  return link.text.startsWith("://");
}

/** A qualified name (A.B) resolves only if its last part does, so a wrong member name is reported too. */
function resolves(checker: ts.TypeChecker, name: ts.Node): boolean {
  return checker.getSymbolAtLocation(name) !== undefined;
}
