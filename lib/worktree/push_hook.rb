require "fileutils"
require "open3"
require "rbconfig"

module RailsWorktree
  class PushHook
    MARKER = "# rails-worktree context hook"

    def self.install(root)
      output, error, status = Open3.capture3(Context::GIT_ENVIRONMENT, "git", "-C", root, "rev-parse", "--git-path", "hooks/pre-push")
      raise Error, "Cannot locate pre-push hook: #{error}" unless status.success?
      path = File.expand_path(output.strip, root)
      return if File.file?(path) && File.read(path).include?(MARKER)
      previous = "#{path}.before-rails-worktree"
      raise Error, "Hook backup already exists: #{previous}; restore it before installing the worktree hook." if File.exist?(previous)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.mv(path, previous) if File.exist?(path)
      File.write(path, <<~RUBY)
        #!#{RbConfig.ruby}
        #{MARKER}
        require "open3"
        require "tempfile"
        root, _, status = Open3.capture3("git", "rev-parse", "--show-toplevel")
        exit 1 unless status.success?
        root = root.strip
        metadata, _, status = Open3.capture3("git", "rev-parse", "--git-path", "rails-worktree.json")
        exit 1 unless status.success?
        Tempfile.create("worktree-push") do |input|
          input.write($stdin.read)
          input.flush
          input.rewind
          if File.file?(File.expand_path(metadata.strip, root))
            launcher = File.join(root, "bin/worktree")
            abort "Missing bin/worktree; reinstall the worktree launcher before pushing." unless File.executable?(launcher)
            exit 1 unless system({"BUNDLE_GEMFILE" => File.join(root, "Gemfile")}, launcher, "verify", "--push", in: input)
          end
          previous = __FILE__ + ".before-rails-worktree"
          if File.executable?(previous)
            input.rewind
            system([previous, previous], *ARGV, in: input)
            exit($?.exitstatus || 128 + $?.termsig)
          end
        end
      RUBY
      File.chmod(0755, path)
    end
  end
end
