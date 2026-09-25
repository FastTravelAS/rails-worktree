module RailsWorktree
  module Commands
    class Exec
      def initialize(args)
        @args = args.dup
        @args.shift if @args.first == "--"
      end

      def run
        context = Context.new
        context.verify
        command = context.command(@args)
        system(context.environment, [command.first, command.first], *command.drop(1), chdir: context.root, unsetenv_others: true)
        status = $?
        exit(status.exitstatus || 128 + status.termsig)
      end
    end
  end
end
