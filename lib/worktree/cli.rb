module RailsWorktree
  class CLI
    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args
    end

    def run
      if @args.empty?
        print_usage
        exit 1
      end

      # Extract flags
      @skip_seeds = @args.delete("--skip-seeds")

      case @args[0]
      when "--close", "close"
        @args.shift
        Commands::Close.new(@args).run
      when "--init", "init"
        @args.shift
        Commands::Init.new(@args, skip_seeds: @skip_seeds).run
      when "--help", "-h", "help"
        print_usage
      else
        # Default: create worktree
        Commands::Create.new(@args, skip_seeds: @skip_seeds).run
      end
    end

    private

    def print_usage
      puts <<~USAGE
        Usage: worktree <name> [base-branch] [options]
               worktree --close [worktree-name]
               worktree --init <worktree-name> [options]

        Creates a new git worktree and initializes it with configuration

        Commands:
          <name>              Create a new worktree with the given name
          --close [name]      Close and remove a worktree
          --init <name>       Initialize a worktree (usually called automatically)
          --help, -h          Show this help message

        Options:
          --skip-seeds        Skip database seeding during initialization

        Arguments:
          <name>              Name of the worktree (required)
          [base-branch]       Branch to create worktree from (default: current branch)

        Examples:
          worktree feature-branch                  # Create new worktree
          worktree feature-branch --skip-seeds     # Create without seeding database
          worktree --close feature-branch          # Close worktree from main repo
          worktree --close                         # Close worktree from within it
      USAGE
    end
  end
end
