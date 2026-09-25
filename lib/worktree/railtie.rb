require "rails/railtie"

module RailsWorktree
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

          RailsWorktree::Launcher.install(Rails.root.to_s)
          Rails.logger.info "✓ Worktree binstub installed! Use: bin/worktree <name>"
        end
      end
    end
  end
end
