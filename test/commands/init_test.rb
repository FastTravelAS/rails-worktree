require "test_helper"

class InitTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @main_worktree = File.join(@tmpdir, "main")
    @worktree_dir = File.join(@tmpdir, "my-feature")
    FileUtils.mkdir_p(@main_worktree)
    FileUtils.mkdir_p(@worktree_dir)

    @init = RailsWorktree::Commands::Init.new(["my-feature"])
    @init.instance_variable_set(:@main_worktree, @main_worktree)
    @init.instance_variable_set(:@db_prefix, "myapp")
    @init.instance_variable_set(:@worktree_name, "my-feature")
    @init.instance_variable_set(:@dev_database_name, "myapp_my-feature_development")
    @init.instance_variable_set(:@test_database_name, "myapp_my-feature_test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- update_database_yml ---

  def test_update_database_yml_with_hardcoded_names
    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("config")
      File.write("config/database.yml", <<~YAML)
        default: &default
          adapter: postgresql

        development:
          <<: *default
          database: myapp_development

        test:
          <<: *default
          database: myapp_test
      YAML

      @init.send(:update_database_yml)
      content = File.read("config/database.yml")

      assert_includes content, "database: myapp_my-feature_development"
      assert_includes content, "database: myapp_my-feature_test"
      refute_match(/database: myapp_development\b/, content)
      refute_match(/database: myapp_test\b/, content)
    end
  end

  def test_update_database_yml_with_erb_env_fetch
    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("config")
      File.write("config/database.yml", <<~YAML)
        default: &default
          adapter: postgresql

        development:
          <<: *default
          database: <%= ENV.fetch("DATABASE_NAME", "myapp_development") %>

        test:
          <<: *default
          database: <%= ENV.fetch("DATABASE_NAME", "myapp_test") %>
      YAML

      @init.send(:update_database_yml)
      content = File.read("config/database.yml")

      assert_includes content, "myapp_my-feature_development"
      assert_includes content, "myapp_my-feature_test"
      refute_includes content, '"myapp_development"'
      refute_includes content, '"myapp_test"'
    end
  end

  def test_update_database_yml_with_env_fetch_separate_vars
    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("config")
      File.write("config/database.yml", <<~YAML)
        default: &default
          adapter: postgresql

        development:
          <<: *default
          database: <%= ENV.fetch("DATABASE_NAME_DEVELOPMENT", "myapp_development") %>

        test:
          <<: *default
          database: <%= ENV.fetch("DATABASE_NAME_TEST", "myapp_test") %>
      YAML

      @init.send(:update_database_yml)
      content = File.read("config/database.yml")

      assert_includes content, "myapp_my-feature_development"
      assert_includes content, "myapp_my-feature_test"
    end
  end

  def test_update_database_yml_no_double_substitution_when_worktree_name_starts_with_test
    @init.instance_variable_set(:@worktree_name, "test-feature")
    @init.instance_variable_set(:@dev_database_name, "myapp_test-feature_development")
    @init.instance_variable_set(:@test_database_name, "myapp_test-feature_test")

    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("config")
      File.write("config/database.yml", <<~YAML)
        default: &default
          adapter: postgresql

        development:
          <<: *default
          database: myapp_development

        test:
          <<: *default
          database: myapp_test
      YAML

      @init.send(:update_database_yml)
      content = File.read("config/database.yml")

      assert_includes content, "database: myapp_test-feature_development"
      assert_includes content, "database: myapp_test-feature_test"
      refute_includes content, "test-feature_test-feature"
    end
  end

  def test_update_database_yml_no_double_substitution_with_queue_databases
    @init.instance_variable_set(:@worktree_name, "test-feature")
    @init.instance_variable_set(:@dev_database_name, "myapp_test-feature_development")
    @init.instance_variable_set(:@test_database_name, "myapp_test-feature_test")

    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("config")
      File.write("config/database.yml", <<~YAML)
        development:
          primary:
            database: myapp_development
          queue:
            database: myapp_development_queue
        test:
          primary:
            database: myapp_test
          queue:
            database: myapp_test_queue
      YAML

      @init.send(:update_database_yml)
      content = File.read("config/database.yml")

      assert_includes content, "database: myapp_test-feature_development"
      assert_includes content, "database: myapp_test-feature_development_queue"
      assert_includes content, "database: myapp_test-feature_test"
      assert_includes content, "database: myapp_test-feature_test_queue"
      refute_includes content, "test-feature_test-feature"
    end
  end

  def test_update_database_yml_skips_when_no_file
    Dir.chdir(@worktree_dir) do
      @init.send(:update_database_yml) # should not raise
    end
  end

  # --- set_database_names ---

  def test_set_database_names_replaces_existing_vars
    Dir.chdir(@worktree_dir) do
      File.write(".env", <<~ENV)
        SOME_VAR=value
        DATABASE_NAME_DEVELOPMENT=myapp_development
        DATABASE_NAME_TEST=myapp_test
        OTHER_VAR=other
      ENV

      @init.send(:set_database_names)
      content = File.read(".env")

      assert_includes content, "DATABASE_NAME_DEVELOPMENT=myapp_my-feature_development"
      assert_includes content, "DATABASE_NAME_TEST=myapp_my-feature_test"
      assert_includes content, "SOME_VAR=value"
      assert_includes content, "OTHER_VAR=other"
    end
  end

  def test_set_database_names_appends_when_missing
    Dir.chdir(@worktree_dir) do
      File.write(".env", "SOME_VAR=value\n")

      @init.send(:set_database_names)
      content = File.read(".env")

      assert_includes content, "DATABASE_NAME_DEVELOPMENT=myapp_my-feature_development"
      assert_includes content, "DATABASE_NAME_TEST=myapp_my-feature_test"
      assert_includes content, "SOME_VAR=value"
    end
  end

  def test_set_database_names_skips_when_no_env_file
    Dir.chdir(@worktree_dir) do
      @init.send(:set_database_names) # should not raise
    end
  end

  # --- get_db_prefix ---

  def test_get_db_prefix_from_hardcoded_database_yml
    FileUtils.mkdir_p(File.join(@main_worktree, "config"))
    File.write(File.join(@main_worktree, "config/database.yml"), <<~YAML)
      development:
        database: valinor_development
    YAML

    result = @init.send(:get_db_prefix)
    assert_equal "valinor", result
  end

  def test_get_db_prefix_falls_back_to_directory_name
    # No database.yml at all
    result = @init.send(:get_db_prefix)
    assert_equal "main", result # File.basename of @main_worktree
  end

  def test_get_db_prefix_ignores_erb_database_yml
    FileUtils.mkdir_p(File.join(@main_worktree, "config"))
    File.write(File.join(@main_worktree, "config/database.yml"), <<~YAML)
      development:
        database: <%= ENV.fetch("DATABASE_NAME_DEVELOPMENT", "valinor_development") %>
    YAML

    # ERB starts with <%=, not a word character, so \w+ won't match
    # Falls back to directory name
    result = @init.send(:get_db_prefix)
    assert_equal "main", result
  end

  # --- setup_database ---

  def test_setup_database_prefers_bin_setup
    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p("bin")
      File.write("bin/setup", "#!/bin/bash\necho setup")
      File.chmod(0755, "bin/setup")

      system_calls = []
      @init.define_singleton_method(:system) do |*args|
        system_calls << args
        true
      end

      @init.send(:setup_database)

      assert_equal 1, system_calls.length
      env, cmd = system_calls[0]
      assert_equal "bin/setup", cmd
      assert_equal "myapp_my-feature_development", env["DATABASE_NAME_DEVELOPMENT"]
      assert_equal "myapp_my-feature_test", env["DATABASE_NAME_TEST"]
    end
  end

  def test_setup_database_falls_back_to_rails_commands
    Dir.chdir(@worktree_dir) do
      # No bin/setup
      system_calls = []
      @init.define_singleton_method(:system) do |*args|
        system_calls << args
        true
      end

      @init.send(:setup_database)

      # Should call: db:create (2x), db:migrate (2x), db:seed (1x) = 5 calls
      assert_equal 5, system_calls.length

      # Verify all calls pass DATABASE_NAME_* env vars
      system_calls.each do |call|
        env = call[0]
        assert_equal "myapp_my-feature_development", env["DATABASE_NAME_DEVELOPMENT"]
        assert_equal "myapp_my-feature_test", env["DATABASE_NAME_TEST"]
      end

      # Verify the commands
      commands = system_calls.map { |c| [c[0]["RAILS_ENV"], c[2]] }
      assert_includes commands, ["development", "db:create"]
      assert_includes commands, ["test", "db:create"]
      assert_includes commands, ["development", "db:migrate"]
      assert_includes commands, ["test", "db:migrate"]
      assert_includes commands, ["development", "db:seed"]
    end
  end

  def test_setup_database_skips_seeds_when_flagged
    @init.instance_variable_set(:@skip_seeds, true)

    Dir.chdir(@worktree_dir) do
      system_calls = []
      @init.define_singleton_method(:system) do |*args|
        system_calls << args
        true
      end

      @init.send(:setup_database)

      # Should call: db:create (2x), db:migrate (2x) = 4 calls, no seed
      assert_equal 4, system_calls.length
      commands = system_calls.map { |c| c[2] }
      refute_includes commands, "db:seed"
    end
  end

  # --- copy_config_files ---

  def test_copy_config_files_copies_existing_files
    Dir.chdir(@worktree_dir) do
      # Create source files in main worktree
      File.write(File.join(@main_worktree, ".env"), "SECRET=123")
      FileUtils.mkdir_p(File.join(@main_worktree, "config"))
      File.write(File.join(@main_worktree, "config/database.yml"), "db: config")
      File.write(File.join(@main_worktree, "Procfile.dev"), "web: rails s")

      @init.send(:copy_config_files)

      assert File.exist?(".env")
      assert File.exist?("config/database.yml")
      assert File.exist?("Procfile.dev")
      assert_equal "SECRET=123", File.read(".env")
    end
  end

  def test_copy_config_files_skips_missing_files
    Dir.chdir(@worktree_dir) do
      # No source files exist
      @init.send(:copy_config_files) # should not raise
    end
  end

  def test_copy_config_files_copies_all_credentials
    Dir.chdir(@worktree_dir) do
      FileUtils.mkdir_p(File.join(@main_worktree, "config/credentials"))
      File.write(File.join(@main_worktree, "config/credentials/development.key"), "dev-key")
      File.write(File.join(@main_worktree, "config/credentials/test.key"), "test-key")
      File.write(File.join(@main_worktree, "config/credentials/test.yml.enc"), "test-enc")

      @init.send(:copy_config_files)

      assert_equal "dev-key", File.read("config/credentials/development.key")
      assert_equal "test-key", File.read("config/credentials/test.key")
      assert_equal "test-enc", File.read("config/credentials/test.yml.enc")
    end
  end
end
