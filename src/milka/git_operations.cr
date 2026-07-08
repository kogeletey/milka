require "uuid"
require "../milka/types/repository_info"
require "../milka/types/git_error"
require "./utils"

# Spinner functionality
SPINNER_CHARS = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

class SpinnerState
  SUCCESS_SYMBOL = "✓"
  FAILURE_SYMBOL = "✗"

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
    color = success ? Utils::ANSI_COLORS[:success] : Utils::ANSI_COLORS[:error]
    symbol = success ? SUCCESS_SYMBOL : FAILURE_SYMBOL
    puts "\r#{color}#{symbol} #{@current_label}#{Utils::ANSI_COLORS[:reset]}"
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

# Helper method to run commands while teeing process output to the terminal.
def run_streaming_command(cmd : String, args : Array(String), chdir : String? = nil)
  stdout_builder = String::Builder.new
  stderr_builder = String::Builder.new

  process = Process.new(
    cmd,
    args,
    output: Process::Redirect::Pipe,
    error: Process::Redirect::Pipe,
    chdir: chdir
  )

  stdout_done = Channel(Nil).new
  stderr_done = Channel(Nil).new

  stream_process_io(process.output, STDOUT, stdout_builder, stdout_done)
  stream_process_io(process.error, STDERR, stderr_builder, stderr_done)

  status = process.wait
  stdout_done.receive
  stderr_done.receive

  {
    success:   status.success?,
    exit_code: status.exit_code,
    stdout:    stdout_builder.to_s,
    stderr:    stderr_builder.to_s,
  }
end

def stream_process_io(source : IO, destination : IO, builder : String::Builder, done : Channel(Nil))
  spawn do
    buffer = Bytes.new(4096)
    loop do
      bytes_read = source.read(buffer)
      break if bytes_read == 0

      chunk = String.new(buffer[0, bytes_read])
      builder << chunk
      destination.print chunk
      destination.flush
    end
  ensure
    done.send(nil)
  end
end

# Helper method to run git commands with consistent error handling and output capture
def run_git_command(cmd : String, args : Array(String), chdir : String? = nil, spinner_id : String? = nil, operation : String? = nil, repo_name : String? = nil)
  stdout_builder = String::Builder.new
  stderr_builder = String::Builder.new

  result = Process.run(
    cmd,
    args,
    output: stdout_builder,
    error: stderr_builder,
    chdir: chdir
  )

  success = result.success?
  stdout_output = stdout_builder.to_s
  stderr_output = stderr_builder.to_s

  if spinner_id
    stop_spinner(spinner_id, success: success)
  end

  unless success
    unless stdout_output.empty?
      Utils.print_info("STDOUT: #{stdout_output.strip}")
    end
    unless stderr_output.empty?
      Utils.print_error("STDERR: #{stderr_output.strip}")
    end
  end

  # Return a hash with all the relevant information
  {
    success:   success,
    exit_code: result.exit_code,
    stdout:    stdout_output,
    stderr:    stderr_output,
  }
end

# Common method to check for authentication errors in git command output
def check_authentication_error(stderr_output : String, repo_url : String, repo_name : String? = nil)
  auth_keywords = [
    "Authentication failed", "Invalid username", "Permission denied",
    "remote: Support for password authentication was removed",
    "fatal: could not read Username",
  ]

  if auth_keywords.any? { |keyword| stderr_output.includes?(keyword) }
    url_to_use = repo_name ? repo_name : repo_url
    raise GitError.authentication_required("Git operation requires authentication for #{url_to_use}")
  end
end

# Git Operations Manager
class GitManager
  def clone_repository(repo : RepositoryInfo)
    # Handle different sources
    case repo.source
    when "git+subtree"
      clone_subtree_repository(repo)
    else
      clone_standard_repository(repo)
    end
  end

  private def clone_standard_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)

    if File.exists?(absolute_local_path)
      Utils.print_info("Repository #{repo.name} already exists at #{absolute_local_path}, skipping clone.")
      return
    end

    begin
      Utils.print_info("Cloning #{repo.name}")
      result = run_streaming_command("git", ["clone", "--progress", "--branch", repo.branch, repo.url, local_path], chdir: current_dir)

      unless result[:success]
        Utils.print_error("Clone failed with status #{result[:exit_code]}. Check above output for details (e.g., network issues, invalid URL, or permissions).")

        check_authentication_error(result[:stderr], repo.url)

        raise GitError.clone_failed("Failed to clone repository #{repo.url} (exit code: #{result[:exit_code]})")
      end

      # Verify clone by checking .git directory
      git_path = File.join(absolute_local_path, ".git")
      unless File.directory?(git_path)
        Utils.print_warning("Warning: .git directory not found in #{absolute_local_path}. Clone may have failed.")
        return
      end

      Utils.print_success("✓ Cloned #{repo.name}")
      add_cloned_directory_to_gitignore(current_dir, local_path)
    rescue e
      raise e
    end
  end

  private def add_cloned_directory_to_gitignore(current_dir : String, local_path : String)
    gitignore_path = File.join(current_dir, ".gitignore")
    repo_dir = "#{local_path}/"

    begin
      gitignore_content = File.exists?(gitignore_path) ? File.read(gitignore_path) : ""
      return if gitignore_content.lines.any? { |line| line.chomp == repo_dir }

      updated_content = append_gitignore_entry(gitignore_content, repo_dir)
      File.write(gitignore_path, updated_content)
      Utils.print_info("Added '#{repo_dir}' to .gitignore")
    rescue e
      Utils.print_warning("Could not update .gitignore: #{e.message}")
    end
  end

  private def append_gitignore_entry(content : String, entry : String) : String
    return "#{entry}\n" if content.empty?

    separator = content.ends_with?("\n") ? "" : "\n"
    "#{content}#{separator}#{entry}\n"
  end

  private def clone_subtree_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    prefix = repo.name

    spinner_id = start_spinner("Adding subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "add", "--prefix", prefix, repo.url, repo.branch, "--squash"], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_add_failed("Failed to add subtree from #{repo.url} to #{prefix}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def fetch_repository(repo : RepositoryInfo)
    # Handle different sources
    case repo.source
    when "git+subtree"
      fetch_subtree_repository(repo)
    else
      fetch_standard_repository(repo)
    end
  end

  private def fetch_standard_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Fetching #{repo.name}")
    begin
      result = run_git_command("git", ["fetch", "origin", repo.branch], chdir: absolute_local_path, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.fetch_failed("Failed to fetch repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  private def fetch_subtree_repository(repo : RepositoryInfo)
    # For subtree, we don't have a separate fetch operation, it's part of pull
    # But we can fetch the remote without doing the merge
    current_dir = Dir.current

    spinner_id = start_spinner("Fetching subtree #{repo.name}")
    begin
      result = run_git_command("git", ["fetch", repo.url, repo.branch], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.fetch_failed("Failed to fetch subtree repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def pull_repository(repo : RepositoryInfo)
    # Handle different sources
    case repo.source
    when "git+subtree"
      pull_subtree_repository(repo)
    else
      pull_standard_repository(repo)
    end
  end

  private def pull_standard_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Pulling #{repo.name}")
    begin
      result = run_git_command("git", ["pull", "origin", repo.branch], chdir: absolute_local_path, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.pull_failed("Failed to pull repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  private def pull_subtree_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    prefix = repo.name

    spinner_id = start_spinner("Pulling subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "pull", "--prefix", prefix, repo.url, repo.branch, "--squash"], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_pull_failed("Failed to pull subtree from #{repo.url}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def push_repository(repo : RepositoryInfo)
    # Handle different sources
    case repo.source
    when "git+subtree"
      push_subtree_repository(repo)
    else
      push_standard_repository(repo)
    end
  end

  private def push_standard_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    local_path = repo.name
    absolute_local_path = File.join(current_dir, local_path)
    unless File.directory?(absolute_local_path)
      raise GitError.config_file_invalid("Repository not cloned: #{repo.name}")
    end

    spinner_id = start_spinner("Pushing #{repo.name}")
    begin
      result = run_git_command("git", ["push", "origin", repo.branch], chdir: absolute_local_path, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.push_failed("Failed to push repository #{repo.name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  private def push_subtree_repository(repo : RepositoryInfo)
    current_dir = Dir.current
    prefix = repo.name

    spinner_id = start_spinner("Pushing subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "push", "--prefix", prefix, repo.url, repo.branch], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_push_failed("Failed to push subtree to #{repo.url}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def process_all_repositories(repositories : Array(RepositoryInfo), command : String)
    repositories.each_with_index do |repo, index|
      action = command.capitalize
      Utils.print_info("[#{index}/#{repositories.size}] #{action} #{repo.name}")
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
