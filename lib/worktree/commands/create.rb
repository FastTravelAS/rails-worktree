module Worktree
  module Commands
    class Create
      def initialize(args)
        @worktree_name = args[0]
        @base_branch = args[1]
      end

      def run
        unless @worktree_name
          puts "Error: Worktree name is required"
          exit 1
        end

        @base_branch ||= current_branch
        worktree_path = "../#{@worktree_name}"

        puts "Creating worktree '#{@worktree_name}' from branch '#{@base_branch}' at #{worktree_path}..."

        unless system("git worktree add -b #{@worktree_name} #{worktree_path} #{@base_branch}")
          puts "Failed to create worktree"
          exit 1
        end

        puts ""
        puts "✓ Worktree created at #{worktree_path}"
        puts ""
        puts "Initializing worktree..."

        Dir.chdir(worktree_path) do
          Init.new([@worktree_name]).run
        end
      end

      private

      def current_branch
        `git branch --show-current`.strip
      end
    end
  end
end
