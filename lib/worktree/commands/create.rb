require "fileutils"

module RailsWorktree
  module Commands
    class Create
      def initialize(args, skip_seeds: false)
        @worktree_name = args[0]
        @base_branch = args[1]
        @skip_seeds = skip_seeds
      end

      def run
        unless @worktree_name
          puts "Error: Worktree name is required"
          exit 1
        end

        raise Error, "Base branch required: bin/worktree #{@worktree_name} BASE (for example origin/main)." unless @base_branch
        context = Context.new
        Dir.chdir(context.root) { create }
      end

      private

      def create
        _output, error, status = Open3.capture3(Context::GIT_ENVIRONMENT, "git", "check-ref-format", "--branch", @worktree_name)
        raise Error, "Invalid worktree branch: #{error.strip}" unless status.success?
        output, error, status = Open3.capture3(Context::GIT_ENVIRONMENT, "git", "rev-parse", "--verify", "--end-of-options", "#{@base_branch}^{commit}")
        raise Error, "Invalid base #{@base_branch}: #{error.strip}" unless status.success?
        base_commit = output.strip
        worktree_dir = ".worktrees"
        worktree_path = "#{worktree_dir}/#{@worktree_name}"
        absolute_path = File.expand_path(worktree_path)

        raise Error, "Worktree name must stay inside .worktrees" unless absolute_path.start_with?(File.expand_path(worktree_dir) + File::SEPARATOR)

        ensure_gitignored(worktree_dir)
        FileUtils.mkdir_p(worktree_dir)

        puts "Creating worktree '#{@worktree_name}' from branch '#{@base_branch}' at #{worktree_path}..."

        unless system(Context::GIT_ENVIRONMENT, "git", "worktree", "add", "-b", @worktree_name, worktree_path, base_commit)
          puts "Failed to create worktree"
          exit 1
        end

        puts ""
        puts "✓ Worktree created at #{worktree_path}"
        puts ""
        puts "Initializing worktree..."

        Dir.chdir(worktree_path) do
          created = Context.new
          created.record(@base_branch, base_commit, @worktree_name)
          created.verify
          Launcher.install(created.root, replace: true)
          PushHook.install(created.root)
          Init.new([@worktree_name], skip_seeds: @skip_seeds).run
        end

        puts ""
        puts "To switch to the new worktree:"
        puts "  cd #{absolute_path}"
        puts ""
        puts "To start the development server: bin/dev"
      end

      def ensure_gitignored(dir)
        gitignore = ".gitignore"
        pattern = "/#{dir}"

        if File.exist?(gitignore)
          return if File.readlines(gitignore).any? { |line| line.strip == pattern }
        end

        File.open(gitignore, "a") { |f| f.puts pattern }
      end
    end
  end
end
