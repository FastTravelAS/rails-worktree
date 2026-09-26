module RailsWorktree
  class Installer
    def self.install(root, replace: false)
      Launcher.install(root, replace: replace)
      ignore_worktrees(root)
    end

    def self.ignore_worktrees(root)
      path = File.join(root, ".gitignore")
      content = File.exist?(path) ? File.read(path) : ""
      return if content.lines.any? { |line| %w[ .worktrees .worktrees/ /.worktrees /.worktrees/ ].include?(line.strip) }

      File.open(path, "a") do |file|
        file.puts unless content.empty? || content.end_with?("\n")
        file.puts "/.worktrees/"
      end
    end
  end
end
