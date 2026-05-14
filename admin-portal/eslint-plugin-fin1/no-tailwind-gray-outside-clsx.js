/**
 * Tailwind `gray-*` utilities must live inside clsx/cn/classNames call trees
 * so light/dark (slate vs gray) branches stay explicit and grepable.
 *
 * @type {import('eslint').Rule.RuleModule}
 */
export default {
  meta: {
    type: 'suggestion',
    docs: {
      description:
        'Disallow Tailwind gray-* class strings except as descendants of clsx(), cn(), or classNames() arguments.',
    },
    messages: {
      default:
        'Put Tailwind gray-* classes inside clsx(..., isDark ? "..." : "text-gray-...") (or use slate tokens). Raw gray outside clsx/cn/classNames is not allowed.',
    },
    schema: [],
  },
  create(context) {
    /** Tailwind color utilities using the gray palette (with optional variant prefixes). */
    const grayTailwind =
      /\b(?:[\w[\]%./-]+:)*(?:text|bg|border|ring|divide|outline|placeholder|from|to|via|shadow)-gray-(?:50|100|200|300|400|500|600|700|800|900|950)\b/;

    /**
     * @param {string} text
     */
    function hasGrayTailwind(text) {
      return typeof text === 'string' && grayTailwind.test(text);
    }

    /**
     * @param {import('estree').Node} node
     */
    function isUnderAllowedCall(node) {
      let p = node.parent;
      while (p) {
        if (p.type === 'CallExpression') {
          const { callee } = p;
          if (callee.type === 'Identifier') {
            if (callee.name === 'clsx' || callee.name === 'cn' || callee.name === 'classNames') {
              return true;
            }
          }
        }
        p = p.parent;
      }
      return false;
    }

    return {
      Literal(node) {
        if (typeof node.value !== 'string' || !hasGrayTailwind(node.value)) return;
        if (isUnderAllowedCall(node)) return;
        context.report({ node, messageId: 'default' });
      },
      TemplateLiteral(node) {
        if (node.expressions.length > 0) return;
        const text = node.quasis.map((q) => q.value.cooked ?? q.value.raw).join('');
        if (!hasGrayTailwind(text)) return;
        if (isUnderAllowedCall(node)) return;
        context.report({ node, messageId: 'default' });
      },
    };
  },
};
