namespace :worktree do
  desc "Install worktree binstub to bin/worktree"
  task :install do
    binstub_path = File.join(Dir.pwd, "bin/worktree")

    if File.exist?(binstub_path)
      puts "Binstub already exists at bin/worktree"
      exit 0
    end

    File.write(binstub_path, <<~RUBY)
      #!/usr/bin/env ruby

      require "bundler/setup"
      require "worktree"

      Worktree::CLI.run(ARGV)
    RUBY

    File.chmod(0755, binstub_path)

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
