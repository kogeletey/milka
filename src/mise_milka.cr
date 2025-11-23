require "toml"
require "uuid"

# Data structures
class RepositoryInfo
  property name : String
  property url : String
  property branch : String
  property latest_commit : String
  property local_path : String

  def initialize(@name : String, @url : String, @branch : String = "main", @latest_commit : String = "")
    @local_path = name
  end
end

class MiseConfig
  property repositories : Array(RepositoryInfo)
  property default_branch : String
  property env : Hash(String, String)?

  def initialize(@repositories : Array(RepositoryInfo), @default_branch : String, @env : Hash(String, String)?)
  end
end

# Exception classes
class GitError < Exception
  def self.clone_failed(message)
    new("Clone failed: #{message}")
  end

  def self.fetch_failed(message)
    new("Fetch failed: #{message}")
  end

  def self.pull_failed(message)
    new("Pull failed: #{message}")
  end

  def self.push_failed(message)
    new("Push failed: #{message}")
  end

  def self.config_file_not_found(message)
    new("Config file not found: #{message}")
  end

  def self.config_file_invalid(message)
    new("Config file invalid: #{message}")
  end

  def self.authentication_required(message)
    new("Authentication required: #{message}. Please provide a username/password or use a personal access token for private repositories.")
  end
end

# Load configuration from TOML file
def load_mise_config(path : String) : MiseConfig
  unless File.exists?(path)
    raise GitError.config_file_not_found("Configuration file not found at: #{path}")
  end

  content = File.read(path)
  repositories = [] of RepositoryInfo

  # Parse TOML content using crystal's TOML library
  begin
    toml_data = TOML.parse(content)

    # Handle the case where the data is an array of repo tables
    if toml_data.has_key?("repo")
      repo_data = toml_data["repo"]

      # Process repo_data based on its actual type
      case repo_data
      when Array
        # If repo_data is already an array, process each element
        repo_data.each do |item|
          # Each item should be a TOML::Any that represents a repo object
          repo_hash = if item.is_a?(Hash)
                        item
                      elsif item.is_a?(TOML::Any)
                        # Check if it can be converted to a hash safely
                        hash_result = item.as_h?
                        if hash_result.nil?
                          raise GitError.config_file_invalid("Repository entry is not a valid object: #{item}")
                        end
                        hash_result
                      else
                        raise GitError.config_file_invalid("Unexpected repository data type: #{item.class}")
                      end

          name = repo_hash["dir"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
          url = repo_hash["remote"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
          branch = repo_hash["branch"]?.try(&.as_s) || "main"
          commit = repo_hash["commit"]?.try(&.as_s) || ""

          repositories << RepositoryInfo.new(name, url, branch, commit)
        end
      when TOML::Any
        # Check if the TOML::Any represents an array or a hash
        if repo_data.as_a?
          # It's an array of objects
          repo_data.as_a.each do |item|
            # Each item should be a TOML::Any that represents a repo object
            repo_hash = if item.is_a?(Hash)
                          item
                        elsif item.is_a?(TOML::Any)
                          # Check if it can be converted to a hash safely
                          hash_result = item.as_h?
                          if hash_result.nil?
                            raise GitError.config_file_invalid("Repository entry is not a valid object: #{item}")
                          end
                          hash_result
                        else
                          raise GitError.config_file_invalid("Unexpected repository data type: #{item.class}")
                        end

            name = repo_hash["dir"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
            url = repo_hash["remote"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
            branch = repo_hash["branch"]?.try(&.as_s) || "main"
            commit = repo_hash["commit"]?.try(&.as_s) || ""

            repositories << RepositoryInfo.new(name, url, branch, commit)
          end
        else
          # It's a single object
          repo_hash = repo_data.as_h
          name = repo_hash["dir"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
          url = repo_hash["remote"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
          branch = repo_hash["branch"]?.try(&.as_s) || "main"
          commit = repo_hash["commit"]?.try(&.as_s) || ""

          repositories << RepositoryInfo.new(name, url, branch, commit)
        end
      else
        raise GitError.config_file_invalid("Unexpected 'repo' data type: #{repo_data.class}")
      end
    end
  rescue e : TOML::ParseException
    raise GitError.config_file_invalid("Invalid TOML format: #{e.message}")
  end

  if repositories.empty?
    print_warning("No repositories found in config. Ensure .meta/reps.toml uses [[repo]] format with 'dir' and 'remote' keys.")
  end

  MiseConfig.new(repositories, "main", nil)
rescue e : File::NotFoundError
  raise GitError.config_file_not_found("Configuration file not found at: #{path}")
end

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

# CLI Helper Functions and Constants
ANSI_COLORS = {
  reset:   "\033[0m",
  info:    "\033[34m", # blue
  success: "\033[32m", # green
  error:   "\033[31m", # red
  warning: "\033[33m", # yellow
}

def print_info(message : String)
  puts "#{ANSI_COLORS[:info]}#{message}#{ANSI_COLORS[:reset]}"
end

def print_success(message : String)
  puts "#{ANSI_COLORS[:success]}#{message}#{ANSI_COLORS[:reset]}"
end

def print_error(message : String)
  puts "#{ANSI_COLORS[:error]}#{message}#{ANSI_COLORS[:reset]}"
end

def print_warning(message : String)
  puts "#{ANSI_COLORS[:warning]}#{message}#{ANSI_COLORS[:reset]}"
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

# Helper functions
def print_usage
  puts <<-USAGE
  Mise Milka - A command-line tool for managing multiple git repositories

  Usage: mise-milka <command> [repo-name] [options]

  Commands:
    clone [repo-name]    Clone a repository or all repositories (if no repo-name provided)
    fetch [repo-name]    Fetch updates for a repository or all repositories (if no repo-name provided)
    pull [repo-name]     Pull latest changes for a repository or all repositories (if no repo-name provided)
    push [repo-name]     Push changes for a repository or all repositories (if no repo-name provided)
    help                 Show this help message

  Options:
    --config <path>      Path to reps.toml configuration file (default: ./.meta/reps.toml)
    --branch <branch>    Specify branch (default: from config or main)

  Examples:
    mise-milka clone                    Clone all repositories from reps.toml
    mise-milka clone my-repo            Clone specific repository
    mise-milka fetch                    Fetch updates for all repositories
    mise-milka fetch my-repo            Fetch updates for specific repository
    mise-milka pull                     Pull latest changes for all repositories
    mise-milka pull my-repo             Pull latest changes for specific repository
    mise-milka push                    Push changes for all repositories
    mise-milka push my-repo             Push changes for specific repository
    mise-milka --config /path/to/reps.toml clone
    mise-milka --config /path/to/reps.toml --branch feature-branch clone my-repo
  USAGE
end

def find_repository_in(repositories : Array(RepositoryInfo), named name : String)
  repositories.find { |repo| repo.name == name }
end

# Command enum as symbols
def get_command_from_string(command_str : String)
  case command_str
  when "clone"
    :clone
  when "fetch"
    :fetch
  when "pull"
    :pull
  when "push"
    :push
  when "help"
    :help
  else
    nil
  end
end

# Main entry point
def main
  args = ARGV
  config_path = ".meta/reps.toml"
  branch_override = nil
  non_option_args = [] of String

  i = 0
  while i < args.size
    arg = args[i]
    if arg == "--config" && i + 1 < args.size
      config_path = args[i + 1]
      i += 2
      next
    elsif arg == "--branch" && i + 1 < args.size
      branch_override = args[i + 1]
      i += 2
      next
    elsif arg.starts_with?("--")
      i += 1
      next
    else
      non_option_args << arg
      i += 1
    end
  end

  if non_option_args.empty?
    print_usage
    exit(1)
  end

  command_string = non_option_args[0] # Should be safe since we checked non_option_args is not empty
  command = get_command_from_string(command_string)

  unless command
    print_error("Error: Invalid command '#{command_string}'")
    print_usage
    exit(1)
  end

  if command == :help
    print_usage
    exit(0)
  end

  repo_name = non_option_args.size > 1 ? non_option_args[1] : nil

  # Load configuration
  begin
    config = load_mise_config(config_path)
    print_info("Loaded #{config.repositories.size} repositories")
  rescue e : GitError
    print_error("❌ Error: #{e.message}")
    exit(1)
  end

  # If no repos loaded, exit early
  if config.repositories.empty?
    print_error("No repositories available to process. Check the warning above and your config file.")
    exit(1)
  end

  # Override branch if specified
  repositories = config.repositories
  if branch_override
    repositories = repositories.map do |repo|
      RepositoryInfo.new(repo.name, repo.url, branch_override, repo.latest_commit)
    end
  end

  git_manager = GitManager.new

  begin
    if repo_name
      repo = find_repository_in(repositories, named: repo_name)
      unless repo
        print_error("❌ Error: Repository '#{repo_name}' not found in configuration")
        exit(1)
      end
      case command
      when :clone
        git_manager.clone_repository(repo)
      when :fetch
        git_manager.fetch_repository(repo)
      when :pull
        git_manager.pull_repository(repo)
      when :push
        git_manager.push_repository(repo)
      end
    else
      git_manager.process_all_repositories(repositories, command.to_s)
    end
  rescue e : GitError
    print_error("❌ Error: #{e.message}")
    exit(1)
  end
end

