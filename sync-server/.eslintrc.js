module.exports = {
  extends: ['eslint:recommended', 'prettier'],
  env: { node: true, es2022: true },
  parserOptions: { ecmaVersion: 2022 },
  rules: {
    'no-console': 'error',
    'no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    'no-var': 'error',
    'prefer-const': 'error',
    'eqeqeq': ['error', 'always'],
    'no-return-await': 'error',
  },
  overrides: [
    {
      files: ['tests/**/*.js'],
      env: { jest: true },
      rules: { 'no-console': 'off' },
    },
  ],
};
