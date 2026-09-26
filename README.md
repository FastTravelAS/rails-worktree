# Rails Worktree

Git worktree management for Rails projects with isolated databases and configurations.

## Features

- Create git worktrees from an explicit base with automatic branch creation
- Run commands with worktree-local Bundler and binstubs
- Verify the recorded base before execution and push
- Isolated databases per worktree (separate development and test databases)
- Automatic configuration file copying
- Copy node_modules from main worktree
- Easy cleanup with database dropping and directory removal

## Installation

Add to your `Gemfile`:

```ruby
group :development do
  gem "rails-worktree"
end
```

Run `bundle install`. A binstub will be automatically created at `bin/worktree`.
When Rails loads in development, installation also adds `/.worktrees/` to the project's
`.gitignore`. The manual installer does the same, including when the binstub already exists.

Manual binstub installation (if needed):
```bash
bundle exec rake worktree:install
```

## Usage

### Create a worktree

```bash
git fetch origin
bin/worktree feature-branch origin/main  # Explicit base required
```

The base is required: omitting it fails before creating a branch or directory. The exact local
commit resolved from that reference is recorded; creation does not fetch or change your base branch.
Worktrees are created under `.worktrees/` in the repository root, including when invoked from a subdirectory.

This creates a new worktree with:
- Separate databases: `myapp_feature-branch_development` and `myapp_feature-branch_test`
- Copied configuration files (`.env`, `database.yml`, `Procfile.dev`, credentials)
- Copied `node_modules`
- Migrated and seeded databases

### Run commands in the worktree

```bash
cd .worktrees/feature-branch
bin/worktree exec -- bundle exec rspec
bin/worktree exec -- bin/rails db:migrate
bin/worktree verify
```

`exec` runs from the Git worktree root, including when called from a subdirectory. It checks the
recorded branch and base ancestry, verifies Bundler's effective root in a fresh Ruby process, and
pins `BUNDLE_GEMFILE` to this worktree. It clears inherited Bundler state and Git directory overrides,
removes other repositories' `bin` directories from PATH, and puts this checkout's `bin` first.
An explicit `bundle` command uses Bundler's gem executable rather than an inherited project binstub.
Initialization commands use the same isolated environment.

Direct commands, `bundle exec` commands, and Ruby script invocations reject binstubs that resolve
into another repository, including symlinks. Arguments are passed directly without shell expansion;
command exit status is preserved. Use an explicit `sh -c` when shell syntax is intended. This wrapper
is an execution-context guard, not a sandbox: it does not inspect shell scripts or prevent application
code from spawning commands elsewhere. Commands run outside the wrapper are not intercepted.

Generated `bin/worktree` launchers are shell scripts that set `BUNDLE_GEMFILE` before starting Ruby,
so an inherited `RUBYOPT=-rbundler/setup` cannot activate the previous checkout's bundle first.
Both automatic installation and the Rake installer use the same generator. To replace an existing
launcher in a project after updating the gem:

```bash
bundle exec rake worktree:install FORCE=1
```

Creation replaces the new worktree's launcher with the current generator. Symlinked launchers
are refused rather than followed. Existing worktrees without recorded metadata cannot use `exec`
or `verify`; create a managed worktree from an explicit base to use these checks.

### Verify before pushing

Creation stores the base reference, its resolved commit, and the feature branch in the private
`rails-worktree.json` file under `git rev-parse --git-dir`. It does not add this metadata to tracked
project files. The recorded commit remains fixed even if the base reference advances.

Creation also installs a pre-push wrapper at Git's configured hook location, including a custom
`core.hooksPath`. An existing hook is preserved as `pre-push.before-rails-worktree` and runs after
verification with the same arguments and input. Its exit status is preserved. Repeated installation
is idempotent; an unexpected existing backup causes an actionable error instead of overwriting it.

In managed worktrees the hook checks the branch, base ancestry, and bundle root, then prints the
change summary against the recorded base. Non-deletion updates must push the current HEAD; push
other branches from their own checkout. In checkouts without metadata, the wrapper only runs the
previous hook. Git hooks are shared by worktrees unless configured otherwise.

A branch mismatch tells you to switch back; a base mismatch tells you to rebase onto the recorded
base. These checks cannot decide whether you chose the right base or whether a change belongs in
the feature. Review the printed diff before publishing. Git's `--no-verify` still bypasses hooks.

### Close a worktree

```bash
bin/worktree --close feature-branch  # From main repo
bin/worktree --close                 # From within worktree
```

Drops both databases, removes the directory, deletes the branch, and cleans up git references.

## Database Configuration

The gem uses environment variables for database names:

- `DATABASE_NAME_DEVELOPMENT` - Development database name
- `DATABASE_NAME_TEST` - Test database name

Your `config/database.yml` should look like:

```yaml
development:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME_DEVELOPMENT", "myapp_development") %>
test:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME_TEST", "myapp_test") %>
```

The gem automatically:
1. Sets these variables in the worktree's `.env` file
2. Updates the worktree's `database.yml` to use them
3. Creates both development and test databases with unique names

## Requirements

- Ruby >= 2.6.0
- Rails project with standard structure
- PostgreSQL (or modify for your database)

## License

MIT
