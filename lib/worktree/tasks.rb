namespace :worktree do
  desc "Install worktree binstub to bin/worktree"
  task :install do
    binstub_path = File.join(Dir.pwd, "bin/worktree")

    if File.exist?(binstub_path) && ENV["FORCE"] != "1"
      puts "Binstub already exists at bin/worktree"
      exit 0
    end

    RailsWorktree::Launcher.install(Dir.pwd, replace: ENV["FORCE"] == "1")

    puts "✓ Worktree binstub installed to bin/worktree"
    puts "Usage: bin/worktree <name>"
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
