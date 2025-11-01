require "rails/railtie"

module Worktree
  class Railtie < Rails::Railtie
    railtie_name :worktree

    rake_tasks do
      load "worktree/tasks.rb"
    end

    initializer "worktree.install_binstub" do
      # Install binstub automatically when Rails loads in development
      if Rails.env.development?
        binstub_path = Rails.root.join("bin/worktree")

        unless File.exist?(binstub_path)
          Rails.logger.info "Installing worktree binstub to bin/worktree..."

          File.write(binstub_path, <<~RUBY)
            #!/usr/bin/env ruby

            require "bundler/setup"
            require "worktree"

            Worktree::CLI.run(ARGV)
          RUBY

          FileUtils.chmod("+x", binstub_path)
          Rails.logger.info "✓ Worktree binstub installed! Use: bin/worktree <name>"
        end
      end
    end
  end
end
