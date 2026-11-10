// Every {@link X} in a doc comment must resolve (tsc never reports one that doesn't). URLs aren't checked.
import type { Rule } from "eslint";
import ts from "typescript";

type Link = ts.JSDocLink | ts.JSDocLinkCode | ts.JSDocLinkPlain;

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
          // jsDoc isn't part of the public node type.
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

function resolves(checker: ts.TypeChecker, name: ts.Node): boolean {
  return checker.getSymbolAtLocation(name) !== undefined;
}
