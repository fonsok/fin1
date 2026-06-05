/**
 * Optional advisory: max line counts (blank lines + comments skipped).
 * Not part of `npm run lint` — use `npm run lint:file-size`.
 * @see Documentation/ADMIN_PORTAL_NAMING_CONVENTIONS.md
 */
import tseslint from 'typescript-eslint';

const ignore = [
  'dist/**',
  'node_modules/**',
  'coverage/**',
  '**/*.{test,spec}.{ts,tsx}',
  'src/test/**',
  'src/vite-env.d.ts',
  '**/*.config.ts',
  '**/*.config.js',
  'eslint.config.js',
  'eslint.filesize.config.js',
];

const maxLines = (max) => [
  'warn',
  { max, skipBlankLines: true, skipComments: true },
];

export default [
  { ignores: ignore },
  {
    files: ['src/pages/**/*Page.tsx'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      'max-lines': maxLines(400),
    },
  },
  {
    files: ['src/**/*.{ts,tsx}'],
    ignores: ['src/pages/**/*Page.tsx'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      'max-lines': maxLines(300),
    },
  },
];
