module RailsWorktree
  class CLI
    def self.run(args)
      new(args).run
    end

    def initialize(args)
      @args = args.dup
    end

    def run
      if @args.empty?
        print_usage
        exit 1
      end

      case @args.first
      when "exec"
        return Commands::Exec.new(@args.drop(1)).run
      when "verify"
        return Context.new.verify(push: @args.include?("--push"))
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
    rescue Error => error
      warn "Error: #{error.message}"
      exit 1
    end

    private

    def print_usage
      puts <<~USAGE
        Usage: worktree <name> <base-branch> [options]
               worktree --close [worktree-name]
               worktree exec -- <command> [arguments]
               worktree verify [--push]
               worktree --init <worktree-name> [options]

        Creates a new git worktree and initializes it with configuration

        Commands:
          <name>              Create a new worktree with the given name
          exec -- COMMAND     Run a command with verified worktree context
          verify              Check the recorded base and bundle root
          --close [name]      Close and remove a worktree
          --init <name>       Initialize a worktree (usually called automatically)
          --help, -h          Show this help message

        Options:
          --skip-seeds        Skip database seeding during initialization

        Arguments:
          <name>              Name of the worktree (required)
          <base-branch>       Explicit branch or commit to create worktree from (required)

        Examples:
          worktree feature-branch origin/main      # Create from an explicit base
          worktree feature-branch origin/main --skip-seeds     # Create without seeding database
          worktree --close feature-branch          # Close worktree from main repo
          worktree --close                         # Close worktree from within it
      USAGE
    end
  end
end
