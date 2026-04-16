# Changelog

## [Unreleased]

### Fixed

- Database name double-substitution when worktree name starts with "test" (e.g. `app_test-worktree_test-worktree_development`). Replaced sequential `gsub!` calls with single-pass `Regexp.union` replacement
- Database drop during close now uses `bin/rails db:drop` instead of bare `dropdb`, picking up connection settings from `database.yml`

### Changed

- Worktrees are now created inside `.worktrees/` in the project root instead of as sibling directories. This preserves tool config (mise, Claude Code, etc.) that depends on being inside the project tree
- `.worktrees` is automatically added to `.gitignore` on first use

## [0.1.6] - 2026-02-11

### Added

- `bin/setup` support: runs project-specific setup script when available during initialization
- `cd` hint after closing a worktree from within it
- Test suite with minitest covering init and close commands

### Fixed

- Database separation: `close` now uses `dropdb` directly instead of `bin/rails db:drop`, ensuring the correct worktree-specific databases are dropped
- Database names in `database.yml` are now replaced via simple string substitution instead of fragile ERB regex, fixing cases where the worktree operated on the main database
- Early `chdir` to main worktree during close to avoid "directory does not exist" errors

## [0.1.5] - 2026-02-11

### Added

- `--skip-seeds` flag to skip database seeding during worktree creation and initialization
- `node_modules` cleanup when closing a worktree
- Support for `bin/setup` during worktree initialization (used when available)

### Changed

- Database names are now passed via environment variables instead of relying on `.env` files
- Improved database prefix detection with fallback to app directory name
- Gemspec now references `RailsWorktree::VERSION` instead of hardcoded version string
- Updated help text with new options and examples

### Fixed

- Database creation and teardown now work reliably without `.env` file dependency
