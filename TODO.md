# Future PR ideas

- [ ] Package and minify extension
- [ ] More docs
- [ ] Format all source code
- [ ] Reload single test file on save not whole suite
- [ ] Lazy test loading/discovery
- [ ] Rspec & Minitest server/plugin?
  - [ ] Can just load the rspec/minitest gems and call into them directly :)
- [ ] Test cache
  - [ ] cache per project (workspaces only, workspace name as key)
  - [ ] store cache in .vscode folder in workspace?
  - [ ] store commit hash
  - [ ] configurable expiry time?
  - [ ] assume cached tests exist on startup, reevaluate modified (vs state of repo at commit) files immediately, lazily reevaluate the rest
