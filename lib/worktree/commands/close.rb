require "fileutils"

module RailsWorktree
  module Commands
    class Close
      def initialize(args)
        @worktree_name = args[0]
        @main_worktree = get_main_worktree
        @current_dir = Dir.pwd
      end

      def run
        detect_worktree_name unless @worktree_name

        @db_prefix = get_db_prefix
        @dev_database_name = "#{@db_prefix}_#{@worktree_name}_development"
        @test_database_name = "#{@db_prefix}_#{@worktree_name}_test"

        detect_paths

        puts "Closing worktree '#{@worktree_name}'..."
        puts "Main worktree: #{@main_worktree}"
        puts ""

        drop_databases
        remove_node_modules
        remove_worktree
        prune_worktrees
        delete_branch

        puts ""
        puts "✓ Worktree '#{@worktree_name}' closed successfully!"
        puts "  Databases dropped: #{@dev_database_name}, #{@test_database_name}"
        puts "  node_modules removed"
        puts "  Worktree removed from #{@worktree_path}"
        puts "  Branch #{@worktree_name} deleted"
      end

      private

      def get_main_worktree
        output = `git worktree list --porcelain`
        output.lines.grep(/^worktree /).first&.split(" ", 2)&.last&.strip
      end

      def detect_worktree_name
        if @current_dir == @main_worktree
          puts "Error: You must specify a worktree name when running from the main repository"
          puts "Usage: worktree --close <worktree-name>"
          puts "  or: cd to the worktree and run: worktree --close"
          exit 1
        else
          @worktree_name = File.basename(@current_dir)
          puts "Detected worktree name: #{@worktree_name}"
        end
      end

      def get_db_prefix
        # Try to get prefix from database.yml first
        database_yml = File.join(@main_worktree, "config/database.yml")
        if File.exist?(database_yml)
          content = File.read(database_yml)
          match = content.match(/database:\s*(\w+)_development/)
          return match[1] if match
        end

        # Fall back to using the Rails app name (directory name of main worktree)
        File.basename(@main_worktree)
      end

      def detect_paths
        if @current_dir == @main_worktree
          @in_main_repo = true
          @worktree_path = File.join(File.dirname(@main_worktree), @worktree_name)
          @worktree_dir = @worktree_path
        else
          @in_main_repo = false
          @worktree_path = @current_dir
          @worktree_dir = "."
        end
      end

      def drop_databases
        puts "Dropping databases..."

        Dir.chdir(@worktree_dir) do
          # Drop development database
          system("RAILS_ENV=development bin/rails db:drop 2>/dev/null") ||
            puts("Warning: Could not drop development database #{@dev_database_name}")

          # Drop test database
          system("RAILS_ENV=test bin/rails db:drop 2>/dev/null") ||
            puts("Warning: Could not drop test database #{@test_database_name}")
        end
      end

      def remove_node_modules
        puts "Removing node_modules..."

        node_modules_path = File.join(@worktree_dir, "node_modules")
        if Dir.exist?(node_modules_path)
          FileUtils.rm_rf(node_modules_path)
          puts "node_modules removed"
        else
          puts "No node_modules to remove"
        end
      end

      def remove_worktree
        puts "Removing worktree..."

        # Change back to main repo if needed
        Dir.chdir(@main_worktree) unless @in_main_repo

        if system("git worktree remove #{@worktree_path} --force 2>/dev/null")
          puts "Worktree removed successfully via git"
        else
          puts "Git worktree remove failed, deleting directory manually..."
          if Dir.exist?(@worktree_path)
            FileUtils.rm_rf(@worktree_path)
            puts "Directory deleted: #{@worktree_path}"
          end
        end
      end

      def prune_worktrees
        system("git worktree prune")
      end

      def delete_branch
        puts "Deleting branch #{@worktree_name}..."
        system("git branch -D #{@worktree_name} 2>/dev/null") ||
          puts("Warning: Could not delete branch #{@worktree_name}")
      end
    end
  end
end
