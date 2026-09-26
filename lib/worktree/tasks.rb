namespace :worktree do
  desc "Install bin/worktree and ignore local .worktrees"
  task :install do
    RailsWorktree::Installer.install(Dir.pwd, replace: ENV["FORCE"] == "1")

    puts "✓ bin/worktree is installed and .worktrees is ignored"
    puts "Usage: bin/worktree <name> <base-branch>"
  end

  desc "Uninstall worktree binstub from bin/worktree"
  task :uninstall do
    binstub_path = File.join(Dir.pwd, "bin/worktree")

    if File.exist?(binstub_path)
      File.delete(binstub_path)
      puts "✓ Worktree binstub removed from bin/worktree"
    else
      puts "Binstub not found at bin/worktree"
    end
  end
end
