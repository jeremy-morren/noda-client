// ESLint rule: every {@link X} / {@linkcode X} / {@linkplain X} in a doc comment must resolve to a declaration, the
// way the TypeScript language service resolves it for hover text and go-to-definition (names in scope, members of the
// enclosing class, qualified names such as {@link Duration.FromDays}). TypeScript itself never reports a link that
// doesn't resolve, so a missing import (e.g. a type mentioned only in docs) or a renamed member goes unnoticed.
// Links to URLs ({@link https://...}) aren't checked.
import ts from "typescript";

/** @type {import("eslint").Rule.RuleModule} */
export default {
  meta: {
    type: "problem",
    docs: { description: "Require {@link} references in doc comments to resolve" },
    messages: {
      unresolved: "{@link {{name}}} doesn't resolve: import the type (import type is enough) or fix the name.",
    },
    schema: [],
  },
  create(context) {
    const services = context.sourceCode.parserServices;
    if (!services?.program) {
      throw new Error("doc-links needs type information (parserOptions.projectService).");
    }
    const checker = services.program.getTypeChecker();
    return {
      Program(node) {
        const sourceFile = services.esTreeNodeToTSNodeMap.get(node);
        const visitDoc = (doc) => {
          if (ts.isJSDocLink(doc) || ts.isJSDocLinkCode(doc) || ts.isJSDocLinkPlain(doc)) {
            if (doc.name && !isUrl(doc) && !resolves(checker, doc.name)) {
              const start = doc.getStart(sourceFile);
              context.report({
                loc: {
                  start: sourceFile.getLineAndCharacterOfPosition(start),
                  end: sourceFile.getLineAndCharacterOfPosition(doc.getEnd()),
                },
                messageId: "unresolved",
                data: { name: doc.name.getText(sourceFile) },
              });
            }
            return;
          }
          ts.forEachChild(doc, visitDoc);
        };
        const visit = (tsNode) => {
          // jsDoc is where the parser attaches doc comments; it isn't part of the public node type.
          for (const doc of tsNode.jsDoc ?? []) {
            visitDoc(doc);
          }
          ts.forEachChild(tsNode, visit);
        };
        visit(sourceFile);
      },
    };
  },
};

/** {@link https://example.com} parses as the name "https" followed by "://example.com". */
function isUrl(link) {
  return link.text.startsWith("://");
}

/** A qualified name (A.B) resolves only if its last part does, so a wrong member name is reported too. */
function resolves(checker, name) {
  return checker.getSymbolAtLocation(name) !== undefined;
}
