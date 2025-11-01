require_relative "worktree/version"
require_relative "worktree/cli"
require_relative "worktree/commands/create"
require_relative "worktree/commands/init"
require_relative "worktree/commands/close"

# Load Railtie only if Rails is available
require_relative "worktree/railtie" if defined?(Rails::Railtie)

module Worktree
  class Error < StandardError; end
end
