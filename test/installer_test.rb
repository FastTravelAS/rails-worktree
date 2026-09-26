require "test_helper"
require "rake"

class InstallerTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("worktree-install")
    @gitignore = File.join(@root, ".gitignore")
    @launcher = File.join(@root, "bin/worktree")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_installs_launcher_and_ignores_local_worktrees
    RailsWorktree::Installer.install(@root)

    assert File.executable?(@launcher)
    assert_equal "/.worktrees/\n", File.read(@gitignore)
  end

  def test_preserves_existing_launcher_and_unterminated_ignore_entry
    FileUtils.mkdir_p(File.dirname(@launcher))
    File.write(@launcher, "existing launcher")
    File.write(@gitignore, "/log")

    2.times { RailsWorktree::Installer.install(@root) }

    assert_equal "existing launcher", File.read(@launcher)
    assert_equal "/log\n/.worktrees/\n", File.read(@gitignore)
  end

  def test_does_not_duplicate_existing_ignore_patterns
    %w[ .worktrees .worktrees/ /.worktrees /.worktrees/ ].each do |pattern|
      File.write(@gitignore, "#{pattern}\n")
      RailsWorktree::Installer.install(@root)
      assert_equal "#{pattern}\n", File.read(@gitignore)
    end
  end

  def test_force_replaces_launcher_and_updates_gitignore
    RailsWorktree::Installer.install(@root)
    File.write(@launcher, "old launcher")
    File.delete(@gitignore)

    RailsWorktree::Installer.install(@root, replace: true)

    assert_includes File.read(@launcher), "BUNDLE_GEMFILE"
    assert File.executable?(@launcher)
    assert_equal "/.worktrees/\n", File.read(@gitignore)
  end

  def test_rake_install_updates_gitignore_when_launcher_exists_and_continues
    RailsWorktree::Launcher.install(@root)
    Rake.with_application do
      load File.expand_path("../lib/worktree/tasks.rb", __dir__)
      Dir.chdir(@root) do
        capture_io { Rake::Task["worktree:install"].invoke }
      end
    end

    assert_equal "/.worktrees/\n", File.read(@gitignore)
  end
end
