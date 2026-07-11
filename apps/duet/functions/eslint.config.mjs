// Flat ESLint config for the Duet Cloud Functions workspace.
// typescript-eslint's `recommended` bundles the core eslint:recommended set.
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['lib/', 'node_modules/'] },
  ...tseslint.configs.recommended,
);
