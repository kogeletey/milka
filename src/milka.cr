require "toml"

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

# Helper functions
def print_usage
  puts <<-USAGE
  Milka - A command-line tool for managing multiple git repositories

  Usage: milka <command> [repo-name] [options]

  Commands:
    clone [repo-name]    Clone a repository or all repositories (if no repo-name provided)
    fetch [repo-name]    Fetch updates for a repository or all repositories (if no repo-name provided)
    pull [repo-name]     Pull latest changes for a repository or all repositories (if no repo-name provided)
    push [repo-name]     Push changes for a repository or all repositories (if no repo-name provided)
    scan                 Scan for git repositories in the current directory and add them to reps.toml
    init                 Initialize a new reps.toml configuration file
    help                 Show this help message

  Options:
    --config <path>      Path to reps.toml configuration file (default: ./.meta/reps.toml)
    --branch <branch>    Specify branch (default: from config or main)

  Examples:
    milka clone                    Clone all repositories from reps.toml
    milka clone my-repo            Clone specific repository
    milka fetch                    Fetch updates for all repositories
    milka fetch my-repo            Fetch updates for specific repository
    milka pull                     Pull latest changes for all repositories
    milka pull my-repo             Pull latest changes for specific repository
    milka push                    Push changes for all repositories
    milka push my-repo             Push changes for specific repository
    milka scan                     Scan current directory for git repos and add to reps.toml
    milka init                     Initialize a new reps.toml configuration file
    milka --config /path/to/reps.toml clone
    milka --config /path/to/reps.toml --branch feature-branch clone my-repo
  USAGE
end

def find_repository_in(repositories : Array(RepositoryInfo), named name : String)
  repositories.find { |repo| repo.name == name }
end

# Function to get git remote information from a git directory
def get_git_remote_info(git_dir : String) : String?
  begin
    # Execute git remote -v to get the remote URLs
    # Use StringBuilders to capture output like in the existing code
    stdout_builder = String::Builder.new
    stderr_builder = String::Builder.new

    result = Process.run(
      "git",
      ["remote", "-v"],
      output: stdout_builder,
      error: stderr_builder,
      chdir: git_dir
    )

    if result.success?
      output = stdout_builder.to_s
      # Parse the output to find the origin remote
      output.each_line do |line|
        if line.includes?("origin") && line.includes?("(fetch)")
          # Extract the URL from the line like: origin	https://github.com/user/repo.git (fetch)
          parts = line.split(/\s+/)
          if parts.size >= 2
            return parts[1]
          end
        end
      end
    end
  rescue
    # If there's an error running git command, return nil
  end

  nil
end

# Function to get the current branch of a git repository
def get_git_branch(git_dir : String) : String
  begin
    # Use StringBuilders to capture output like in the existing code
    stdout_builder = String::Builder.new
    stderr_builder = String::Builder.new

    result = Process.run(
      "git",
      ["rev-parse", "--abbrev-ref", "HEAD"],
      output: stdout_builder,
      error: stderr_builder,
      chdir: git_dir
    )

    if result.success?
      branch = stdout_builder.to_s.strip
      return branch unless branch.empty?
    end
  rescue
    # If there's an error, return default branch
  end

  "main"  # Default branch
end

# Function to check if a repository is already in the config
def repo_exists_in_config(config_path : String, dir_name : String) : Bool
  return false unless File.exists?(config_path)

  begin
    content = File.read(config_path)
    toml_data = TOML.parse(content)

    if toml_data.has_key?("repo")
      repo_data = toml_data["repo"]

      case repo_data
      when Array
        repo_data.each do |item|
          repo_hash = if item.is_a?(Hash)
                        item
                      elsif item.is_a?(TOML::Any)
                        hash_result = item.as_h?
                        return false if hash_result.nil?
                        hash_result
                      else
                        next
                      end

          existing_dir = repo_hash["dir"]?.try(&.as_s)
          return true if existing_dir == dir_name
        end
      when TOML::Any
        if repo_data.as_a?
          repo_data.as_a.each do |item|
            repo_hash = if item.is_a?(Hash)
                          item
                        elsif item.is_a?(TOML::Any)
                          hash_result = item.as_h?
                          next if hash_result.nil?
                          hash_result
                        else
                          next
                        end

            existing_dir = repo_hash["dir"]?.try(&.as_s)
            return true if existing_dir == dir_name
          end
        else
          repo_hash = repo_data.as_h
          existing_dir = repo_hash["dir"]?.try(&.as_s)
          return true if existing_dir == dir_name
        end
      end
    end
  rescue
    # If there's an error parsing the config, return false
  end

  false
end

# Function to add a git repository to the reps.toml file
def add_git_repo_to_config(config_path : String, dir_name : String, remote_url : String, branch : String)
  # Create the directory if it doesn't exist
  config_dir = File.dirname(config_path)
  Dir.mkdir_p(config_dir) unless File.directory?(config_dir)

  # Check if the repository already exists in the config
  return if repo_exists_in_config(config_path, dir_name)

  # Format the entry in TOML format
  new_entry = "\n[[repo]]\n"
  new_entry += "dir = '#{dir_name}'\n"
  new_entry += "remote = '#{remote_url}'\n"
  new_entry += "branch = '#{branch}'\n\n"

  # Append the new entry to the config file
  File.open(config_path, "a") do |file|
    file.puts(new_entry)
  end
end

# Main function to scan directories and add git repositories to config
def scan_and_add_git_repos(config_path : String, root_path : String = ".")
  print_info("Scanning for git repositories in: #{root_path}")

  git_dirs = scan_git_directories(root_path)

  if git_dirs.empty?
    print_warning("No git repositories found in: #{root_path}")
    return
  end

  print_info("Found #{git_dirs.size} git repositories")

  added_count = 0
  git_dirs.each do |git_dir|
    dir_name = File.basename(git_dir)

    print_info("Checking git repository: #{dir_name}")

    # Get the remote URL
    remote_url = get_git_remote_info(git_dir)
    if remote_url.nil?
      print_warning("  No remote found for #{dir_name}, skipping...")
      next
    end

    # Get the current branch
    branch = get_git_branch(git_dir)

    print_info("  Remote: #{remote_url}")
    print_info("  Branch: #{branch}")

    # Add to config if not already present
    add_git_repo_to_config(config_path, dir_name, remote_url, branch)
    print_success("  Added #{dir_name} to config")
    added_count += 1
  end

  print_success("Scan completed! Added #{added_count} repositories to #{config_path}")
end

# Function to initialize the reps.toml configuration file
def init_config(config_path : String)
  # Check if the config file already exists
  if File.exists?(config_path)
    print_error("❌ Error: Configuration file already exists at: #{config_path}")
    print_info("💡 To create a new configuration, remove the existing file first or use a different path.")
    print_info("   Use: milka --config <new_path> init")
    raise GitError.config_file_invalid("Configuration file already exists: #{config_path}")
  end

  # Extract directory path from config_path
  config_dir = File.dirname(config_path)

  # Create the directory if it doesn't exist
  Dir.mkdir_p(config_dir) unless File.directory?(config_dir)

  # Define the template content for reps.toml
  template_content = <<-'TOML'
  # Milka - Repository Configuration

  # Add your repositories to this file using the format below
  # [[repo]]
  # dir = 'project'
  # remote = 'https://github.com/username/my-project.git'
  # branch = 'develop'
  TOML

  # Write the template to the config file
  File.write(config_path, template_content.strip)

  print_success("✅ Configuration file created at: #{config_path}")
  print_info("💡 Edit #{config_path} to add your repositories:")
  print_info("   - Replace 'my-project' with your local directory name")
  print_info("   - Replace 'https://github.com/username/my-project.git' with your repository URL")
  print_info("   - Set the appropriate branch (default: 'main')")
  print_info("   - Add more repositories by duplicating the [[repo]] block")
end

# Function to scan directories and identify git repositories
def scan_git_directories(root_path : String = ".") : Array(String)
  git_directories = [] of String

  Dir.glob("#{root_path}/**/*").each do |path|
    next unless File.directory?(path)

    git_path = File.join(path, ".git")
    if File.directory?(git_path)
      # Get the directory name (last component of path)
      dir_name = File.basename(path)
      git_directories << path
    end
  end

  git_directories
end

