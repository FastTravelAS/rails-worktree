# Rails Worktree

A Ruby gem for managing git worktrees in Rails projects with isolated databases and configurations.

## Features

- Create git worktrees with automatic branch creation
- Isolated database per worktree (separate database name)
- Automatic configuration file copying (.env, database.yml, etc.)
- Copy node_modules from main worktree
- Easy cleanup with database dropping and directory removal
- Works across any Rails project (no hardcoded paths)

## Installation

### In your Rails project Gemfile

```ruby
# Add to Gemfile (development group)
group :development do
  gem "rails-worktree"
end
```

Then run:

```bash
bundle install
```

The gem will automatically install a binstub to `bin/worktree` when Rails loads in development mode.

### Manual binstub installation

If needed, you can manually install or reinstall the binstub:

```bash
bundle exec rake worktree:install
```

To uninstall:

```bash
bundle exec rake worktree:uninstall
```

### Global installation (optional)

If you want to use `worktree` command globally:

```bash
gem install rails-worktree
```

## Usage

### Create a new worktree

```bash
bin/worktree feature-branch
# Creates worktree from current branch

bin/worktree feature-branch main
# Creates worktree from main branch
```

This will:
1. Create a new git worktree in `../feature-branch`
2. Create a new branch called `feature-branch`
3. Copy configuration files from main worktree
4. Set up a separate database (e.g., `myapp_feature-branch`)
5. Copy node_modules
6. Run migrations and seed the database

### Close a worktree

```bash
# From main repository:
bin/worktree --close feature-branch

# From within the worktree:
bin/worktree --close
```

This will:
1. Drop the worktree's database
2. Remove the worktree directory
3. Delete the branch
4. Clean up git worktree references

### Manual initialization (advanced)

If you need to manually initialize a worktree:

```bash
cd ../feature-branch
worktree --init feature-branch
```

## How it works

### Database isolation

The gem automatically:
- Detects your main database name from `config/database.yml`
- Creates a new database with pattern: `{app_name}_{worktree_name}`
- Updates the worktree's `.env` to set `DATABASE_NAME`
- Modifies `database.yml` to use the `DATABASE_NAME` environment variable

### Configuration files

The following files are copied from the main worktree:
- `.env`
- `config/database.yml`
- `Procfile.dev`
- `config/credentials/development.key`

### Node modules

If `node_modules` exists in the main worktree, it will be copied to the new worktree.

## Requirements

- Ruby >= 2.6.0
- Git with worktree support
- Rails project with standard structure

## Project structure

This gem works with Rails projects that follow the standard structure:

```
your-project/
├── config/
│   ├── database.yml
│   └── credentials/
│       └── development.key
├── .env
├── Procfile.dev
└── bin/
    ├── rails
    └── dev
```

## Development

To work on the gem:

```bash
# Clone or create the gem
cd worktree

# Make changes to lib/worktree/**

# Test locally
gem build worktree.gemspec
gem install ./worktree-0.1.0.gem

# Test in a Rails project
cd /path/to/rails/project
worktree test-branch
```

## License

MIT

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
