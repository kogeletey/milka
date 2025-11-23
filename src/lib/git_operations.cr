require "uuid"

# Git Operations Manager
class GitManager
  def clone_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)

    if File.exists?(absolute_local_path)
      print_info("Repository #{repo.name} already exists at #{absolute_local_path}, skipping clone.")
      return
    end

    spinner_id = start_spinner("Cloning #{repo.name}")
    begin
      # Use StringBuilders to capture output
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["clone", "--branch", repo.branch, repo.url, local_path],
        output: stdout_builder,
        error: stderr_builder,
        chdir: current_dir
      )

      success = result.success?
      stdout_output = stdout_builder.to_s
      stderr_output = stderr_builder.to_s

      stop_spinner(spinner_id, success: success)

      unless success
        unless stdout_output.empty?
          print_info("STDOUT: #{stdout_output.strip}")
        end
        unless stderr_output.empty?
          print_error("STDERR: #{stderr_output.strip}")
        end

        print_error("Clone failed with status #{result.exit_code}. Check above output for details (e.g., network issues, invalid URL, or permissions).")

        auth_keywords = [
          "Authentication failed", "Invalid username", "Permission denied",
          "remote: Support for password authentication was removed",
          "fatal: could not read Username",
        ]

        if auth_keywords.any? { |keyword| stderr_output.includes?(keyword) }
          raise GitError.authentication_required("Git operation requires authentication for #{repo.url}")
        end

        raise GitError.clone_failed("Failed to clone repository #{repo.url} (exit code: #{result.exit_code})")
      end

      # Verify clone by checking .git directory
      git_path = File.join(absolute_local_path, ".git")
      unless File.directory?(git_path)
        print_warning("Warning: .git directory not found in #{absolute_local_path}. Clone may have failed.")
        return
      end

      # Add cloned directory to .gitignore
      gitignore_path = File.join(current_dir, ".gitignore")
      repo_dir = "#{local_path}/"
      gitignore_content = ""
      should_add = true

      if File.exists?(gitignore_path)
        begin
          gitignore_content = File.read(gitignore_path)
          should_add = !gitignore_content.includes?(repo_dir)
        rescue e
          print_warning("Could not read .gitignore: #{e.message}")
        end
      end

      if should_add
        if gitignore_content.empty?
          gitignore_content = repo_dir
        else
          gitignore_content += "\n#{repo_dir}"
        end
        begin
          File.write(gitignore_path, gitignore_content)
          print_info("Added '#{repo_dir}' to .gitignore")
        rescue e
          print_warning("Could not update .gitignore: #{e.message}")
        end
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def fetch_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Fetching #{repo.name}")
    begin
      # Use StringBuilders to capture output
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["fetch", "origin", repo.branch],
        output: stdout_builder,
        error: stderr_builder,
        chdir: absolute_local_path
      )

      success = result.success?
      stdout_output = stdout_builder.to_s
      stderr_output = stderr_builder.to_s

      stop_spinner(spinner_id, success: success)

      unless success
        unless stdout_output.empty?
          print_info("STDOUT: #{stdout_output.strip}")
        end
        unless stderr_output.empty?
          print_error("STDERR: #{stderr_output.strip}")
        end

        auth_keywords = [
          "Authentication failed", "Invalid username", "Permission denied",
          "remote: Support for password authentication was removed",
          "fatal: could not read Username",
        ]

        if auth_keywords.any? { |keyword| stderr_output.includes?(keyword) }
          raise GitError.authentication_required("Git operation requires authentication for #{repo.name}")
        end

        raise GitError.fetch_failed("Failed to fetch repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def pull_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Pulling #{repo.name}")
    begin
      # Use StringBuilders to capture output
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["pull", "origin", repo.branch],
        output: stdout_builder,
        error: stderr_builder,
        chdir: absolute_local_path
      )

      success = result.success?
      stdout_output = stdout_builder.to_s
      stderr_output = stderr_builder.to_s

      stop_spinner(spinner_id, success: success)

      unless success
        unless stdout_output.empty?
          print_info("STDOUT: #{stdout_output.strip}")
        end
        unless stderr_output.empty?
          print_error("STDERR: #{stderr_output.strip}")
        end

        auth_keywords = [
          "Authentication failed", "Invalid username", "Permission denied",
          "remote: Support for password authentication was removed",
          "fatal: could not read Username",
        ]

        if auth_keywords.any? { |keyword| stderr_output.includes?(keyword) }
          raise GitError.authentication_required("Git operation requires authentication for #{repo.name}")
        end

        raise GitError.pull_failed("Failed to pull repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def push_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Pushing #{repo.name}")
    begin
      # Use StringBuilders to capture output
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["push", "origin", repo.branch],
        output: stdout_builder,
        error: stderr_builder,
        chdir: absolute_local_path
      )

      success = result.success?
      stdout_output = stdout_builder.to_s
      stderr_output = stderr_builder.to_s

      stop_spinner(spinner_id, success: success)

      unless success
        unless stdout_output.empty?
          print_info("STDOUT: #{stdout_output.strip}")
        end
        unless stderr_output.empty?
          print_error("STDERR: #{stderr_output.strip}")
        end

        auth_keywords = [
          "Authentication failed", "Invalid username", "Permission denied",
          "remote: Support for password authentication was removed",
          "fatal: could not read Username",
        ]

        if auth_keywords.any? { |keyword| stderr_output.includes?(keyword) }
          raise GitError.authentication_required("Git operation requires authentication for #{repo.name}")
        end

        raise GitError.push_failed("Failed to push repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def process_all_repositories(repositories : Array(RepositoryInfo), command : String)
    repositories.each_with_index do |repo, index|
      action = command.capitalize
      print_info("[#{index}/#{repositories.size}] #{action} #{repo.name}")
      case command
      when "clone"
        clone_repository(repo)
      when "fetch"
        fetch_repository(repo)
      when "pull"
        pull_repository(repo)
      when "push"
        push_repository(repo)
      end
    end
  end
end

# Spinner functionality
SPINNER_CHARS = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

class SpinnerState
  property is_active : Bool
  property current_id : String
  property current_label : String

  def initialize
    @is_active = false
    @current_id = ""
    @current_label = ""
  end

  def start(label : String)
    id = UUID.random.to_s[0..7]
    @current_id = id
    @current_label = label
    @is_active = true
    id
  end

  def stop(id : String, success : Bool)
    return unless @current_id == id
    @is_active = false
    color = success ? ANSI_COLORS[:success] : ANSI_COLORS[:error]
    symbol = success ? "✅" : "❌"
    print "\r#{color}#{symbol} #{@current_label}#{ANSI_COLORS[:reset]}"
    @current_id = ""
    @current_label = ""
  end

  def is_active_and_id_matches?(id : String) : Bool
    @is_active && @current_id == id
  end
end

SPINNER_STATE = SpinnerState.new

def start_spinner(label : String)
  SPINNER_STATE.start(label)
end

def stop_spinner(id : String, success : Bool)
  SPINNER_STATE.stop(id, success)
end