# Testing

## Overview

The `vscode` namespace used by this extension is not available outside of the Visual Studio Code [Extension Host](https://code.visualstudio.com/api/advanced-topics/extension-host "Visual Studio Code API docs"). As a result the test setup is a little convoluted.

## Running tests

There are three groups of tests included in the repository.

- Tests for Ruby scripts to collect test information and run tests
  - Run with `bundle exec rake` in `ruby` directory.
- Tests for VS Code extension which invokes the Ruby scripts.
  - Run from VS Code's debug panel with the "Run tests for" configurations.
    - There are separate debug configurations for each supported test framework.
    - Note that you'll need to run `npm run build && npm run package` before you'll be able to successfully run the extension tests. You'll also need to re-run these every time you make changes to the extension code or your tests.
  - Run from npm (automatically runs `npm run build && npm run package` before running tests)
    - `npm run test:rspec` - Rspec integration tests
    - `npm run test:minitest` - Minitest integration tests
    - `npm run test:unit` - Unit tests

You can see `.github/workflows/test.yml` for CI configurations.

## Test Architecture

The test folders are structured as follows:

- tests
  - fixtures
    - minitest
    - rspec
  - stubs
  - suite
    - minitest
    - rspec
    - unitTests
  - runFrameworkTests.ts

When you run a test suite, the entry point is `runFrameworkTests.ts`. This file uses `@vscode/test-electron` to download a clean instance of VS Code, then uses the first argument passed to it as the name of the suite it should run.

It looks in the `suite` folder for a folder with the name of the test suite which contains one or more test files matching the filename glob `*.test.ts`, then passes these in an array along with the relevant `fixtures` folder (if there is one) to `test-electron`'s test runner.

This then launches a new instance of VS Code which runs through all the test cases given to it, printing results to `stdout`.

The `stubs` folder is for stub implementations of types that are useful for tests, such as `NOOP_LOGGER`.
