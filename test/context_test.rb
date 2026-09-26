require "test_helper"
require "open3"
require "rbconfig"

class ContextTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("worktree context ")
    @main = File.join(@directory, "main app")
    @child = File.join(@directory, "feature app")
    FileUtils.mkdir_p(@main)
    git(@main, "init", "--quiet", "--initial-branch=main")
    git(@main, "config", "user.name", "Test")
    git(@main, "config", "user.email", "test@example.test")
    @gem_root = File.expand_path("..", __dir__)
    File.write(File.join(@main, "Gemfile"), "source 'https://rubygems.org'\ngem 'rails-worktree', path: #{@gem_root.inspect}\n")
    FileUtils.mkdir_p(File.join(@main, "bin"))
    File.write(File.join(@main, "bin/setup"), <<~'SH')
      #!/bin/sh
      printf '%s\n' "$BUNDLE_GEMFILE" > setup-context
    SH
    File.chmod(0755, File.join(@main, "bin/setup"))
    File.write(File.join(@main, ".gitignore"), "/.worktrees\n/bin/worktree\n")
    env = Bundler.unbundled_env.merge("BUNDLE_GEMFILE" => File.join(@main, "Gemfile"))
    _, error, status = Open3.capture3(env, RbConfig.ruby, Gem.bin_path("bundler", "bundle"), "lock", "--local", chdir: @main, unsetenv_others: true)
    raise error unless status.success?
    git(@main, "add", ".")
    git(@main, "commit", "--quiet", "-m", "base")
    @base = git(@main, "rev-parse", "HEAD").strip
    git(@main, "worktree", "add", "--quiet", "-b", "feature", @child, "main")
    @context = RailsWorktree::Context.new(@child)
    @context.record("main", @base, "feature")
    RailsWorktree::Launcher.install(@child)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_verifies_recorded_base_and_rejects_different_branch
    assert_equal @base, @context.verify.fetch("commit")
    git(@child, "switch", "-c", "other")
    error = assert_raises(RailsWorktree::Error) { @context.verify }
    assert_includes error.message, "switch back"
  end

  def test_rejects_invalid_metadata_and_external_gemfile
    File.write(@context.metadata_path, "{")
    assert_raises(RailsWorktree::Error) { @context.verify }
    @context.record("main", @base, "feature")
    File.delete(File.join(@child, "Gemfile"))
    File.symlink(File.join(@main, "Gemfile"), File.join(@child, "Gemfile"))
    assert_raises(RailsWorktree::Error) { @context.verify }
  end

  def test_exec_pins_bundle_and_working_directory_and_preserves_arguments
    File.open(File.join(@main, "Gemfile"), "a") { |file| file.puts 'gem "missing-worktree-test-gem"' }
    code = 'require "bundler"; puts Bundler.root.realpath; puts Dir.pwd; puts ARGV'
    output, error, status = launcher("exec", "--", "bundle", "exec", "ruby", "-e", code, "two words", "--skip-seeds", env: {
      "BUNDLE_GEMFILE" => File.join(@main, "Gemfile"),
      "PATH" => "#{@main}/bin:#{ENV.fetch("PATH")}",
      "RUBYOPT" => "-rbundler/setup"
    })
    assert status.success?, error
    assert_equal [@child, @child, "two words", "--skip-seeds"], output.lines.map(&:strip)
  end

  def test_exec_propagates_failure_without_interpreting_shell_characters
    output, error, status = launcher("exec", "ruby", "-e", 'puts ARGV; exit 7', "$(touch unwanted)")
    assert_equal 7, status.exitstatus, error
    assert_equal "$(touch unwanted)\n", output
    refute File.exist?(File.join(@child, "unwanted"))
  end

  def test_exec_rejects_foreign_and_symlinked_project_binstubs
    FileUtils.mkdir_p(File.join(@main, "bin"))
    foreign = File.join(@main, "bin/rake")
    File.write(foreign, "#!/bin/sh\nexit 0\n")
    File.chmod(0755, foreign)
    File.symlink(foreign, File.join(@child, "bin/rake"))
    [[foreign], ["bin/rake"], ["bundle", "exec", "rake"], ["ruby", foreign], ["bundle", "exec", "ruby", foreign]].each do |arguments|
      error = assert_raises(RailsWorktree::Error) { @context.command(arguments) }
      assert_includes error.message, "outside this worktree"
    end
  end

  def test_exec_uses_local_binstub_instead_of_inherited_worktree_path
    File.write(File.join(@child, "bin/probe"), "#!/bin/sh\nprintf local")
    File.chmod(0755, File.join(@child, "bin/probe"))
    output, error, status = launcher("exec", "probe", env: {"PATH" => "#{@main}/bin:#{ENV.fetch("PATH")}"})
    assert status.success?, error
    assert_equal "local", output
  end

  def test_creation_requires_explicit_base_without_mutating_repository
    Dir.chdir(@main) do
      assert_raises(RailsWorktree::Error) { RailsWorktree::Commands::Create.new(["new-feature"]).run }
      refute Dir.exist?(".worktrees")
    end
  end

  def test_creation_records_requested_base_instead_of_current_branch
    File.write(File.join(@main, "unrelated"), "unrelated commit")
    git(@main, "add", "unrelated")
    git(@main, "commit", "--quiet", "-m", "unrelated")
    File.delete(File.join(@main, ".gitignore"))
    Dir.chdir(File.join(@main, "bin")) { RailsWorktree::Commands::Create.new(["new-feature", @base]).run }
    created = RailsWorktree::Context.new(File.join(@main, ".worktrees/new-feature"))
    assert_equal File.join(created.root, "Gemfile"), File.read(File.join(created.root, "setup-context")).strip
    assert_equal @base, created.verify.fetch("commit")
    assert_equal @base, git(created.root, "rev-parse", "HEAD").strip
    refute File.exist?(File.join(created.root, "unrelated"))
    assert File.executable?(File.join(created.root, "bin/worktree"))
    assert_equal "/.worktrees/\n", File.read(File.join(@main, ".gitignore"))
    assert_equal ".worktrees/new-feature/\n", git(@main, "check-ignore", ".worktrees/new-feature/")
    refute File.exist?(File.join(@directory, "new-feature"))
    refute File.exist?(File.join(@main, "bin/.worktrees"))
    refute_includes git(created.root, "status", "--porcelain"), "rails-worktree.json"
  end

  def test_hook_chains_existing_hook_with_arguments_and_stdin
    hook = File.expand_path(git(@child, "rev-parse", "--git-path", "hooks/pre-push").strip, @child)
    File.write(hook, "#!/bin/sh\ncat > hook-input\nprintf '%s' \"$1\" > hook-remote\nexit 9\n")
    File.chmod(0755, hook)
    RailsWorktree::PushHook.install(@child)
    RailsWorktree::PushHook.install(@child)
    output, error, status = Open3.capture3(@context.environment, hook, "origin", "url", stdin_data: "refs/heads/feature #{@base} refs/heads/feature #{"0" * 40}\n", chdir: @child, unsetenv_others: true)
    assert_equal 9, status.exitstatus, error
    assert_includes output, @base
    assert_equal "refs/heads/feature #{@base} refs/heads/feature #{"0" * 40}\n", File.read(File.join(@child, "hook-input"))
    assert_equal "origin", File.read(File.join(@child, "hook-remote"))
    git(@child, "switch", "-c", "unexpected")
    _, error, status = Open3.capture3(@context.environment, [hook, hook], chdir: @child, unsetenv_others: true)
    assert_equal 1, status.exitstatus
    assert_includes error, "switch back"
  end

  def test_rejects_a_recorded_base_outside_the_branch_history
    tree = git(@main, "rev-parse", "HEAD^{tree}").strip
    unrelated = git(@main, "commit-tree", tree, "-m", "unrelated root").strip
    @context.record("unrelated", unrelated, "feature")
    error = assert_raises(RailsWorktree::Error) { @context.verify }
    assert_includes error.message, "Rebase onto that base"
  end

  def test_hook_uses_custom_hook_directory_and_skips_unmanaged_checkout
    git(@main, "config", "core.hooksPath", File.join(@main, "custom hooks"))
    RailsWorktree::PushHook.install(@child)
    path = File.join(@main, "custom hooks/pre-push")
    assert File.executable?(path)
    _, error, status = Open3.capture3(@context.environment, [path, path], chdir: @main, unsetenv_others: true)
    assert status.success?, error
  end

  def test_hook_rejects_pushes_of_another_commit
    RailsWorktree::PushHook.install(@child)
    path = File.expand_path(git(@child, "rev-parse", "--git-path", "hooks/pre-push").strip, @child)
    input = "refs/heads/other #{"a" * 40} refs/heads/other #{"0" * 40}\n"
    _, error, status = Open3.capture3(@context.environment, [path, path], stdin_data: input, chdir: @child, unsetenv_others: true)
    assert_equal 1, status.exitstatus
    assert_includes error, "Push the current branch separately"
  end

  def test_missing_or_symlinked_launchers_are_not_overwritten_elsewhere
    path = File.join(@child, "bin/worktree")
    File.delete(path)
    target = File.join(@main, "keep")
    File.write(target, "keep")
    File.symlink(target, path)
    assert_raises(RailsWorktree::Error) { RailsWorktree::Launcher.install(@child, replace: true) }
    assert_equal "keep", File.read(target)
  end

  def test_git_push_runs_the_installed_verifier
    remote = File.join(@directory, "remote.git")
    FileUtils.mkdir_p(remote)
    git(remote, "init", "--bare", "--quiet")
    git(@child, "remote", "add", "origin", remote)
    RailsWorktree::PushHook.install(@child)
    output, error, status = Open3.capture3(@context.environment, "git", "push", "origin", "feature", chdir: @child, unsetenv_others: true)
    assert status.success?, error
    assert_includes output, @base
    assert_equal @base, git(remote, "rev-parse", "feature").strip
  end

  private

  def git(directory, *arguments)
    output, error, status = Open3.capture3("git", "-C", directory, *arguments)
    raise error unless status.success?
    output
  end

  def launcher(*arguments, env: {})
    Open3.capture3(@context.environment.merge(env), File.join(@child, "bin/worktree"), *arguments, chdir: @child, unsetenv_others: true)
  end
end
