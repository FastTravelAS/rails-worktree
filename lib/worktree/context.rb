require "json"
require "open3"
require "rbconfig"
require "bundler"

module RailsWorktree
  class Context
    GIT_ENVIRONMENT = {"GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil}.freeze

    attr_reader :root

    def initialize(directory = Dir.pwd)
      @root = File.realpath(git(directory, "rev-parse", "--show-toplevel").strip)
    end

    def record(base, commit, branch)
      File.write(metadata_path, JSON.pretty_generate({"base" => base, "commit" => commit, "branch" => branch}) + "\n")
    end

    def verify(push: false)
      data = JSON.parse(File.read(metadata_path))
      raise Error, "Invalid worktree context in #{metadata_path}; expected an object with base, commit and branch." unless data.is_a?(Hash)
      verify_branch(data)
      verify_base(data)
      verify_bundle
      verify_push(data) if push
      data
    rescue Errno::ENOENT, JSON::ParserError, KeyError => error
      raise Error, "Missing or invalid worktree context. Recreate with an explicit base using worktree NAME BASE. #{error.message}"
    end

    def environment
      env = Bundler.respond_to?(:unbundled_env) ? Bundler.unbundled_env : Bundler.clean_env
      env["PATH"] = executable_path(env.fetch("PATH", ""))
      env["BUNDLE_GEMFILE"] = File.join(root, "Gemfile")
      env.delete("BUNDLE_BIN_PATH")
      GIT_ENVIRONMENT.each_key { |key| env.delete(key) }
      env
    end

    def command(arguments)
      raise Error, "Command required: bin/worktree exec -- bundle exec rspec" if arguments.empty?
      arguments = arguments.dup
      invoked = arguments[0, 2] == ["bundle", "exec"] ? arguments.drop(2) : arguments
      candidates = invoked.first == "bundle" ? [] : [invoked.first]
      candidates << invoked[1] if invoked.first && File.basename(invoked.first) == "ruby"
      candidates.compact.each { |path| verify_binstub(path) }
      if arguments.first == "bundle"
        arguments.shift
        [RbConfig.ruby, Gem.bin_path("bundler", "bundle"), *arguments]
      else
        arguments
      end
    end

    def metadata_path
      File.expand_path(git(root, "rev-parse", "--git-path", "rails-worktree.json").strip, root)
    end

    private

    def executable_path(path)
      worktree_bins = git(root, "worktree", "list", "--porcelain").lines.grep(/^worktree /).map do |line|
        File.join(line.delete_prefix("worktree ").strip, "bin")
      end
      paths = path.split(File::PATH_SEPARATOR).reject do |directory|
        worktree_bins.include?(directory) || foreign_bin_directory?(directory)
      end
      ([File.join(root, "bin")] + paths).uniq.join(File::PATH_SEPARATOR)
    end

    def verify_branch(data)
      branch = git(root, "branch", "--show-current").strip
      raise Error, "Worktree branch differs from recorded #{data.fetch("branch")}; switch back before continuing." unless branch == data.fetch("branch")
    end

    def verify_base(data)
      git(root, "merge-base", "--is-ancestor", data.fetch("commit"), "HEAD")
    rescue Error
      raise Error, "Recorded base #{data.fetch("base")} is no longer an ancestor of HEAD. Rebase onto that base before continuing."
    end

    def verify_bundle
      gemfile = File.join(root, "Gemfile")
      raise Error, "Missing worktree Gemfile: #{gemfile}" unless File.file?(gemfile) && File.realpath(gemfile) == gemfile

      output, error, status = Open3.capture3(environment, RbConfig.ruby, "-rbundler", "-e", "puts Bundler.root.realpath", chdir: root, unsetenv_others: true)
      unless status.success? && output.strip == root
        raise Error, "Bundle resolves outside this worktree or cannot load. Run through bin/worktree exec. #{error.strip}"
      end
    end

    def verify_push(data)
      unless $stdin.tty?
        head = git(root, "rev-parse", "HEAD").strip
        $stdin.each_line do |line|
          _local_ref, sha, _remote_ref, _remote_sha = line.split
          next if sha && sha.match?(/\A0+\z/)
          raise Error, "Push includes a commit other than this worktree's HEAD. Push the current branch separately." unless sha == head
        end
      end
      puts "Worktree base: #{data.fetch("base")} (#{data.fetch("commit")})"
      puts git(root, "diff", "--stat", "#{data.fetch("commit")}...HEAD", "--")
    end

    def foreign_bin_directory?(path)
      return false unless File.basename(path) == "bin" && File.directory?(path)
      output, _error, status = Open3.capture3(GIT_ENVIRONMENT, "git", "-C", path, "rev-parse", "--show-toplevel")
      status.success? && File.realpath(output.strip) != root
    end

    def verify_binstub(path)
      resolved = if path.include?(File::SEPARATOR)
        File.expand_path(path, root)
      else
        environment.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, path) }.find { |file| File.executable?(file) && !File.directory?(file) }
      end
      return unless resolved && File.exist?(resolved)
      resolved = File.realpath(resolved)
      return if resolved.start_with?(root + File::SEPARATOR)
      return unless resolved.include?("/bin/")
      _output, _error, status = Open3.capture3(GIT_ENVIRONMENT, "git", "-C", File.dirname(resolved), "rev-parse", "--show-toplevel")
      raise Error, "Binstub resolves outside this worktree: #{resolved}. Use this checkout's binstub through bin/worktree exec." if status.success?
    end

    def git(directory, *arguments)
      output, error, status = Open3.capture3(GIT_ENVIRONMENT, "git", "-C", directory, *arguments)
      raise Error, "Git context check failed (#{arguments.join(" ")}): #{error.strip}" unless status.success?
      output
    end
  end
end
