require "fileutils"

module RailsWorktree
  module Commands
    # Drops the worktree-local databases recorded in .env.*.local, removes the
    # checkout and deletes its branch.
    class Close
      def initialize(args)
        @worktree_name = args[0]
        @named = !@worktree_name.nil?
        @main_worktree = get_main_worktree
        @current_dir = Dir.pwd
      end

      def run
        detect_worktree_name unless @worktree_name
        detect_paths

        puts "Closing worktree '#{@worktree_name}'..."
        puts "Main worktree: #{@main_worktree}"
        puts ""

        drop_databases
        remove_node_modules

        # Move to main worktree so we're not inside the directory we're about to delete
        Dir.chdir(@main_worktree) unless @in_main_repo
        remove_worktree
        prune_worktrees
        delete_branch

        puts ""
        puts "✓ Worktree '#{@worktree_name}' closed successfully!"
        puts "  Worktree removed from #{@worktree_path}"
        puts "  Branch #{@branch} deleted" if @branch_deleted

        if @worktree_path == @current_dir
          puts ""
          puts "Run: cd #{@main_worktree}"
        end
      end

      private

      def get_main_worktree
        output = `git worktree list --porcelain`
        output.lines.grep(/^worktree /).first&.split(" ", 2)&.last&.strip
      end

      def detect_worktree_name
        if @current_dir == @main_worktree
          raise Error, "Specify a worktree name when closing from the main repository: bin/worktree close NAME"
        else
          @worktree_name = File.basename(@current_dir)
          puts "Detected worktree name: #{@worktree_name}"
        end
      end

      # Finds the checkout in git's worktree list by directory name or branch, so
      # worktrees outside .worktrees/ (git worktree add, herdr, Claude Code) close too.
      # An explicit name wins over the current directory, so closing another
      # worktree from inside one leaves the current checkout alone.
      def detect_paths
        @in_main_repo = @current_dir == @main_worktree
        entries = worktree_entries.reject { |entry| entry[:path] == @main_worktree }
        entry = if @named
          entries.find { |candidate| candidate[:path] == File.join(@main_worktree, ".worktrees", @worktree_name) } ||
            entries.find { |candidate| File.basename(candidate[:path]) == @worktree_name || candidate[:branch] == @worktree_name }
        else
          entries.find { |candidate| candidate[:path] == @current_dir }
        end
        raise Error, "No worktree named #{@worktree_name}; see git worktree list." if @named && !entry

        @worktree_path = entry ? entry[:path] : @current_dir
        @branch = entry ? entry[:branch] : @worktree_name
      end

      def worktree_entries
        `git worktree list --porcelain`.split("\n\n").map do |block|
          lines = block.lines.map(&:strip)
          path = lines.find { |line| line.start_with?("worktree ") }&.delete_prefix("worktree ")
          branch = lines.find { |line| line.start_with?("branch ") }&.delete_prefix("branch refs/heads/")
          {path: path, branch: branch}
        end
      end

      def config
        @config ||= Config.load(File.exist?(File.join(@worktree_path, Config::FILE)) ? @worktree_path : @main_worktree)
      end

      # Databases named in the worktree's .env.development.local and .env.test.local.
      # Without those files the checkout shares the main databases, which stay untouched.
      def worktree_databases
        Init::ENV_FILES.filter_map do |environment, file|
          path = File.join(@worktree_path, file)
          next unless File.file?(path)

          variable = environment == "test" ? config.test_variable : config.development_variable
          match = File.read(path).match(/^#{Regexp.escape(variable)}=(.+)$/)
          [environment, variable, match[1].strip] if match
        end
      end

      def drop_databases
        databases = worktree_databases
        if databases.empty?
          puts "No worktree-local databases in .env.development.local or .env.test.local; nothing to drop"
          return
        end
        unless File.executable?(File.join(@worktree_path, "bin/rails"))
          puts "Warning: bin/rails not found in worktree, skipping database drop"
          return
        end

        Dir.chdir(@worktree_path) do
          databases.each do |environment, variable, database|
            puts "Dropping #{database}..."
            env = {"RAILS_ENV" => environment, variable => database, "DISABLE_DATABASE_ENVIRONMENT_CHECK" => "1"}
            system(env, "bin/rails", "db:drop") || puts("Warning: could not drop #{database}")
          end
        end
      end

      def remove_node_modules
        node_modules_path = File.join(@worktree_path, "node_modules")
        return unless File.exist?(node_modules_path) || File.symlink?(node_modules_path)

        puts "Removing node_modules..."
        FileUtils.rm_rf(node_modules_path)
      end

      def remove_worktree
        puts "Removing worktree..."
        if system(Context::GIT_ENVIRONMENT, "git", "worktree", "remove", "--force", @worktree_path, err: File::NULL)
          puts "Worktree removed successfully via git"
        elsif Dir.exist?(@worktree_path)
          puts "Git worktree remove failed, deleting directory manually..."
          FileUtils.rm_rf(@worktree_path)
          puts "Directory deleted: #{@worktree_path}"
        end
      end

      def prune_worktrees
        system("git", "worktree", "prune")
      end

      def delete_branch
        return puts("No branch to delete (detached HEAD)") unless @branch

        puts "Deleting branch #{@branch}..."
        @branch_deleted = system("git", "branch", "-D", @branch, err: File::NULL)
        puts("Warning: Could not delete branch #{@branch}") unless @branch_deleted
      end
    end
  end
end
