require "fileutils"

module RailsWorktree
  module Commands
    class Init
      def initialize(args, skip_seeds: false)
        @worktree_name = args[0]
        @skip_seeds = skip_seeds
      end

      def run
        unless @worktree_name
          puts "Error: Worktree name is required"
          puts "Usage: worktree --init <worktree-name>"
          exit 1
        end

        @main_worktree = get_main_worktree
        @db_prefix = get_db_prefix
        @dev_database_name = "#{@db_prefix}_#{@worktree_name}_development"
        @test_database_name = "#{@db_prefix}_#{@worktree_name}_test"

        puts "Initializing worktree '#{@worktree_name}'..."
        puts "Main worktree: #{@main_worktree}"
        puts "Development database: #{@dev_database_name}"
        puts "Test database: #{@test_database_name}"

        copy_config_files
        set_database_names
        update_database_yml
        copy_node_modules
        setup_database

        puts ""
        puts "✓ Worktree initialized successfully!"
        puts "  Development database: #{@dev_database_name}"
        puts "  Test database: #{@test_database_name}"
        puts "  Configuration files copied"
      end

      private

      def get_main_worktree
        output = `git worktree list --porcelain`
        output.lines.grep(/^worktree /).first&.split(" ", 2)&.last&.strip
      end

      def get_db_prefix
        # Try to get prefix from database.yml first
        database_yml = File.join(@main_worktree, "config/database.yml")
        if File.exist?(database_yml)
          content = File.read(database_yml)
          match = content.match(/database:\s*(\w+)_development/)
          return match[1] if match
        end

        # Fall back to using the Rails app name (directory name of main worktree)
        File.basename(@main_worktree)
      end

      def copy_config_files
        puts "Copying configuration files..."

        files_to_copy = [
          ".env",
          "config/database.yml",
          "Procfile.dev",
          "config/master.key"
        ]

        files_to_copy += Dir.glob("config/credentials/*", base: @main_worktree)

        files_to_copy.each do |file|
          source = File.join(@main_worktree, file)
          if File.exist?(source)
            FileUtils.mkdir_p(File.dirname(file)) unless File.directory?(File.dirname(file))
            FileUtils.cp(source, file)
          else
            puts "Warning: #{file} not found, skipping"
          end
        end
      end

      def set_database_names
        puts "Setting database names in .env..."

        env_file = ".env"
        return unless File.exist?(env_file)

        content = File.read(env_file)

        # Set development database name
        if content.match?(/^DATABASE_NAME_DEVELOPMENT=/)
          content.gsub!(/^DATABASE_NAME_DEVELOPMENT=.*$/, "DATABASE_NAME_DEVELOPMENT=#{@dev_database_name}")
        else
          content += "\nDATABASE_NAME_DEVELOPMENT=#{@dev_database_name}\n"
        end

        # Set test database name
        if content.match?(/^DATABASE_NAME_TEST=/)
          content.gsub!(/^DATABASE_NAME_TEST=.*$/, "DATABASE_NAME_TEST=#{@test_database_name}")
        else
          content += "DATABASE_NAME_TEST=#{@test_database_name}\n"
        end

        File.write(env_file, content)
      end

      def update_database_yml
        puts "Updating database.yml to use separate database names..."

        database_yml = "config/database.yml"
        return unless File.exist?(database_yml)

        content = File.read(database_yml)

        # Use a single-pass replacement to avoid one substitution creating
        # a substring that matches the other pattern (e.g., replacing
        # "app_development" first produces "app_test-branch_development",
        # which contains "app_test" and would be wrongly matched by a
        # second gsub for the test pattern).
        replacements = {
          "#{@db_prefix}_development" => @dev_database_name,
          "#{@db_prefix}_test" => @test_database_name
        }
        pattern = Regexp.union(replacements.keys)
        content.gsub!(pattern) { |match| replacements[match] }

        File.write(database_yml, content)
      end

      def copy_node_modules
        source = File.join(@main_worktree, "node_modules")
        dest = "node_modules"

        if Dir.exist?(source) && !Dir.exist?(dest)
          puts "Copying node_modules from main worktree..."
          FileUtils.cp_r(source, dest)
          puts "Note: node_modules copied."
        end
      end

      def database_env
        {
          "DATABASE_NAME_DEVELOPMENT" => @dev_database_name,
          "DATABASE_NAME_TEST" => @test_database_name
        }
      end

      def setup_database
        if File.executable?("bin/setup")
          puts "Running bin/setup..."
          system(database_env, "bin/setup") || puts("Warning: bin/setup failed")
        else
          puts "Creating databases..."
          system(database_env.merge("RAILS_ENV" => "development"), "bin/rails", "db:create") || puts("Warning: Could not create development database")
          system(database_env.merge("RAILS_ENV" => "test"), "bin/rails", "db:create") || puts("Warning: Could not create test database")

          puts "Running migrations..."
          system(database_env.merge("RAILS_ENV" => "development"), "bin/rails", "db:migrate") || puts("Warning: Could not run migrations")
          system(database_env.merge("RAILS_ENV" => "test"), "bin/rails", "db:migrate") || puts("Warning: Could not run test migrations")

          unless @skip_seeds
            puts "Seeding development database..."
            system(database_env.merge("RAILS_ENV" => "development"), "bin/rails", "db:seed") || puts("Warning: Could not seed database")
          else
            puts "Skipping database seeding..."
          end
        end
      end
    end
  end
end
