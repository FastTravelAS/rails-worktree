require "test_helper"

class CloseTest < Minitest::Test
  include RepositoryFixture

  def setup
    build_repository
    write_main("bin/rails", "#!/bin/sh\n")
    FileUtils.cp_r(File.join(@main, "bin"), @worktree)
    File.chmod(0755, File.join(@worktree, "bin/rails"))
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_drops_only_the_databases_recorded_in_the_local_env_files
    File.write(File.join(@worktree, ".env.development.local"), "# generated\nDATABASE_NAME=myapp_feature_x_development\n")
    File.write(File.join(@worktree, ".env.test.local"), "DATABASE_NAME=myapp_feature_x_test\n")
    close = build_close

    close.send(:drop_databases)

    assert_equal [["development", "myapp_feature_x_development"], ["test", "myapp_feature_x_test"]],
      close.calls.map { |env, *| [env["RAILS_ENV"], env["DATABASE_NAME"]] }
    close.calls.each do |env, command, task|
      assert_equal "1", env["DISABLE_DATABASE_ENVIRONMENT_CHECK"]
      assert_equal ["bin/rails", "db:drop"], [command, task]
    end
  end

  def test_uses_the_configured_variables
    write_main(".worktree.yml", "database:\n  development_variable: DATABASE_NAME_DEVELOPMENT\n  test_variable: DATABASE_NAME_TEST\n")
    File.write(File.join(@worktree, ".env.development.local"), "DATABASE_NAME_DEVELOPMENT=myapp_feature_x_development\n")
    File.write(File.join(@worktree, ".env.test.local"), "DATABASE_NAME=ignored\n")
    close = build_close

    close.send(:drop_databases)

    assert_equal [["development", "myapp_feature_x_development"]], close.calls.map { |env, *| [env["RAILS_ENV"], env["DATABASE_NAME_DEVELOPMENT"]] }
  end

  def test_leaves_shared_databases_alone_without_local_env_files
    close = build_close
    _out, _err = capture_io { close.send(:drop_databases) }
    assert_empty close.calls
  end

  def test_skips_the_drop_without_bin_rails
    File.delete(File.join(@worktree, "bin/rails"))
    File.write(File.join(@worktree, ".env.development.local"), "DATABASE_NAME=myapp_feature_x_development\n")
    close = build_close
    out, _err = capture_io { close.send(:drop_databases) }
    assert_includes out, "skipping database drop"
    assert_empty close.calls
  end

  def test_removes_a_node_modules_symlink_without_touching_the_target
    write_main("node_modules/left-pad/index.js", "1")
    File.symlink(File.join(@main, "node_modules"), File.join(@worktree, "node_modules"))
    close = build_close

    capture_io { close.send(:remove_node_modules) }

    refute File.symlink?(File.join(@worktree, "node_modules"))
    assert File.file?(File.join(@main, "node_modules/left-pad/index.js"))
  end

  def test_close_from_within_the_worktree_removes_checkout_and_branch
    Dir.chdir(@worktree) { capture_io { RailsWorktree::Commands::Close.new([]).run } }

    refute Dir.exist?(@worktree)
    refute_includes git(@main, "branch", "--list", "feature-x"), "feature-x"
  end

  def test_close_from_the_main_checkout_requires_a_name
    Dir.chdir(@main) { assert_raises(RailsWorktree::Error) { RailsWorktree::Commands::Close.new([]).run } }
    Dir.chdir(@main) { capture_io { RailsWorktree::Commands::Close.new(["feature-x"]).run } }
    refute Dir.exist?(@worktree)
  end

  def test_close_from_the_main_checkout_finds_worktrees_outside_the_worktrees_directory
    outside = File.join(@directory, "claude-checkout")
    git(@main, "worktree", "add", "--quiet", "-b", "claude/thing", outside, "main")

    Dir.chdir(@main) { capture_io { RailsWorktree::Commands::Close.new(["claude-checkout"]).run } }

    refute Dir.exist?(outside)
    assert_empty git(@main, "branch", "--list", "claude/thing")
  end

  def test_close_from_the_main_checkout_rejects_unknown_names
    Dir.chdir(@main) { assert_raises(RailsWorktree::Error) { RailsWorktree::Commands::Close.new(["missing"]).run } }
  end

  def test_close_by_name_from_another_worktree_removes_only_the_named_one
    other = File.join(@main, ".worktrees", "feature-y")
    git(@main, "worktree", "add", "--quiet", "-b", "feature-y", other, "main")

    Dir.chdir(other) { capture_io { RailsWorktree::Commands::Close.new(["feature-x"]).run } }

    refute Dir.exist?(@worktree)
    assert_empty git(@main, "branch", "--list", "feature-x")
    assert Dir.exist?(other)
    refute_empty git(@main, "branch", "--list", "feature-y")
  end

  def test_close_by_unknown_name_from_a_worktree_is_rejected
    Dir.chdir(@worktree) { assert_raises(RailsWorktree::Error) { RailsWorktree::Commands::Close.new(["missing"]).run } }
    assert Dir.exist?(@worktree)
  end

  private

  def build_close
    close = Dir.chdir(@worktree) { RailsWorktree::Commands::Close.new([]) }
    close.instance_variable_set(:@worktree_name, "feature-x")
    close.send(:detect_paths)
    calls = []
    close.define_singleton_method(:calls) { calls }
    close.define_singleton_method(:system) do |*args, **_options|
      calls << args
      true
    end
    close
  end
end
