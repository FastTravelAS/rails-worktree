module RailsWorktree
  class Error < StandardError; end
end

require_relative "worktree/version"
require_relative "worktree/context"
require_relative "worktree/launcher"
require_relative "worktree/installer"
require_relative "worktree/push_hook"
require_relative "worktree/cli"
require_relative "worktree/commands/create"
require_relative "worktree/commands/init"
require_relative "worktree/commands/close"
require_relative "worktree/commands/exec"

# Load Railtie only if Rails is available
require_relative "worktree/railtie" if defined?(Rails::Railtie)
