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
        Installer.install(Rails.root.to_s)
      end
    end
  end
end
