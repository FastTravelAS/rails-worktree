require "fileutils"

module Worktree
  module Commands
    class Init
      def initialize(args)
        @worktree_name = args[0]
      end

      def run
        unless @worktree_name
          puts "Error: Worktree name is required"
          puts "Usage: worktree --init <worktree-name>"
          exit 1
        end

        @main_worktree = get_main_worktree
        @db_prefix = get_db_prefix
        @database_name = "#{@db_prefix}_#{@worktree_name}"

        puts "Initializing worktree '#{@worktree_name}'..."
        puts "Main worktree: #{@main_worktree}"
        puts "Database: #{@database_name}"

        copy_config_files
        set_database_name
        update_database_yml
        copy_node_modules
        setup_database

        puts ""
        puts "✓ Worktree initialized successfully!"
        puts "  Database: #{@database_name}"
        puts "  Configuration files copied"
        puts ""
        puts "To start the development server: bin/dev"
      end

      private

      def get_main_worktree
        output = `git worktree list --porcelain`
        output.lines.grep(/^worktree /).first&.split(" ", 2)&.last&.strip
      end

      def get_db_prefix
        database_yml = File.join(@main_worktree, "config/database.yml")
        return nil unless File.exist?(database_yml)

        content = File.read(database_yml)
        match = content.match(/database:\s*(\w+)_development/)
        match ? match[1] : nil
      end

      def copy_config_files
        puts "Copying configuration files..."

        files_to_copy = [
          ".env",
          "config/database.yml",
          "Procfile.dev",
          "config/credentials/development.key"
        ]

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

      def set_database_name
        puts "Setting DATABASE_NAME=#{@database_name} in .env..."

        env_file = ".env"
        return unless File.exist?(env_file)

        content = File.read(env_file)
        if content.match?(/^DATABASE_NAME=/)
          content.gsub!(/^DATABASE_NAME=.*$/, "DATABASE_NAME=#{@database_name}")
        else
          content += "\nDATABASE_NAME=#{@database_name}\n"
        end

        File.write(env_file, content)
      end

      def update_database_yml
        puts "Updating database.yml to use DATABASE_NAME..."

        database_yml = "config/database.yml"
        return unless File.exist?(database_yml)

        content = File.read(database_yml)
        content.gsub!(
          /database:\s*#{@db_prefix}_development/,
          "database: <%= ENV.fetch(\"DATABASE_NAME\", \"#{@db_prefix}_development\") %>"
        )

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

      def setup_database
        puts "Creating database #{@database_name}..."
        system("RAILS_ENV=development bin/rails db:create") || puts("Warning: Could not create database")

        puts "Running migrations..."
        system("RAILS_ENV=development bin/rails db:migrate") || puts("Warning: Could not run migrations")

        puts "Seeding database..."
        system("RAILS_ENV=development bin/rails db:seed") || puts("Warning: Could not seed database")
      end
    end
  end
end
