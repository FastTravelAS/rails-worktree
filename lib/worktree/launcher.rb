require "fileutils"

module RailsWorktree
  class Launcher
    def self.install(root, replace: false)
      path = File.join(root, "bin/worktree")
      return if File.exist?(path) && !replace
      FileUtils.mkdir_p(File.dirname(path))
      raise Error, "Launcher points outside this worktree: #{path}" unless File.realpath(File.dirname(path)).start_with?(File.realpath(root) + File::SEPARATOR)
      raise Error, "Refusing to replace a symlinked launcher: #{path}" if File.symlink?(path)
      File.write(path, <<~'SH')
        #!/bin/sh
        # Set the bundle before Ruby processes an inherited -rbundler/setup.
        worktree_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
        export BUNDLE_GEMFILE="$worktree_root/Gemfile"
        unset BUNDLE_BIN_PATH
        exec ruby -e 'require "bundler/setup"; require "rails-worktree"; RailsWorktree::CLI.run(ARGV)' -- "$@"
      SH
      File.chmod(0755, path)
    end
  end
end
