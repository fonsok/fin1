import eslint from '@eslint/js';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import globals from 'globals';
import tseslint from 'typescript-eslint';
import fin1 from './eslint-plugin-fin1/index.js';

export default tseslint.config(
  { ignores: ['dist/**', 'node_modules/**', 'coverage/**'] },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      globals: globals.browser,
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
      fin1,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      // Viele bestehende Muster (Pagination, Filter → Seite 0) sind bewusst – optional später aufräumen.
      'react-hooks/set-state-in-effect': 'off',
      'react-hooks/preserve-manual-memoization': 'off',
      'react-refresh/only-export-components': 'off',
      'fin1/no-tailwind-gray-outside-clsx': 'error',
    },
  },
  {
    files: [
      'eslint.config.js',
      'vite.config.ts',
      'vitest.config.ts',
      'postcss.config.js',
      'tailwind.config.js',
    ],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    files: ['**/*.{test,spec}.{ts,tsx}', 'src/test/**'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      'fin1/no-tailwind-gray-outside-clsx': 'off',
    },
  },
);
