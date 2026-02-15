require "./command_factory"
require "./utils"
require "./config_manager"

# Helper functions for backward compatibility (for tests)
def load_mise_config(path : String)
  ConfigManager.load_mise_config(path)
end

def find_repository_in(repositories : Array(RepositoryInfo), named name : String)
  Utils.find_repository_in(repositories, named: name)
end

def init_config(config_path : String)
  RepositoryUtils.init_config(config_path)
end

def get_command_from_string(command_string : String)
  case command_string
  when "clone"
    :clone
  when "fetch"
    :fetch
  when "pull"
    :pull
  when "push"
    :push
  when "scan"
    :scan
  when "create"
    :create
  when "remote"
    :remote
  when "issues"
    :issues
  {% if flag?(:github_plugin) %}when "github"
    :github
  {% end %}when "help"
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
  use_subtree = false
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
    elsif arg == "--subtree"
      use_subtree = true
      i += 1
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
    Utils.print_usage
    exit(0)
  end

  command_string = non_option_args[0]

  if command_string == "help"
    Utils.print_usage
    exit(0)
  end

  command = CommandFactory.create_command(command_string, config_path, branch_override)

  unless command
    Utils.print_error("Error: Invalid command '#{command_string}'")
    Utils.print_usage
    exit(1)
  end

  repo_name = non_option_args.size > 1 ? non_option_args[1] : nil
  additional_args = non_option_args.size > 2 ? non_option_args[2..-1] : [] of String

  # Initialize repositories variable
  repositories = [] of RepositoryInfo

  # Check if this is a URL-based clone operation
  is_url_clone = command_string == "clone" &&
                 non_option_args.size >= 2 &&
                 (non_option_args[1].starts_with?("http://") || non_option_args[1].starts_with?("https://"))

  # Also check for the reverse case: custom_name URL
  is_url_clone = is_url_clone || (
    command_string == "clone" &&
    non_option_args.size >= 3 &&
    (non_option_args[2].starts_with?("http://") || non_option_args[2].starts_with?("https://"))
  )

  # Load configuration for commands that need it (not for scan, create, remote, issues, or github commands)
  # Also skip loading config if this is a URL clone operation
  # Issues and github commands can work without config if a URL/org-name is provided
  {% if flag?(:github_plugin) %}
  skip_config_load = command_string == "scan" || command_string == "init" || command_string == "create" || command_string == "remote" || command_string == "issues" || command_string == "github" || is_url_clone
  {% else %}
  skip_config_load = command_string == "scan" || command_string == "init" || command_string == "create" || command_string == "remote" || command_string == "issues" || is_url_clone
  {% end %}
  if !skip_config_load
    begin
      config = ConfigManager.load_mise_config(config_path)
      Utils.print_info("Loaded #{config.repositories.size} repositories")
      repositories = config.repositories

      # Override branch if specified
      if branch_override
        repositories = repositories.map do |repo|
          RepositoryInfo.new(repo.name, repo.url, branch_override, repo.latest_commit, repo.source)
        end
      end
    rescue e : GitError
      Utils.print_error("❌ Error: #{e.message}")
      exit(1)
    end

    # If no repos loaded, exit early (for commands that need config)
    if repositories.empty?
      Utils.print_error("No repositories available to process. Check the warning above and your config file.")
      exit(1)
    end
  elsif command_string == "issues"
    # Issues command: try to load config but don't fail if not found
    begin
      config = ConfigManager.load_mise_config(config_path)
      repositories = config.repositories
      if branch_override
        repositories = repositories.map do |repo|
          RepositoryInfo.new(repo.name, repo.url, branch_override, repo.latest_commit, repo.source)
        end
      end
    rescue e : GitError
      # Config is optional for issues command, can work with URL directly
      repositories = [] of RepositoryInfo
    end
  end

  begin
    # Create the correct command with subtree flag
    command = CommandFactory.create_command(command_string, config_path, branch_override, use_subtree)

    unless command
      Utils.print_error("Error: Invalid command '#{command_string}' after processing flags")
      Utils.print_usage
      exit(1)
    end

    {% if flag?(:github_plugin) %}
    needs_additional_args = command_string == "scan" || command_string == "create" || command_string == "remote" || command_string == "clone" || command_string == "issues" || command_string == "github"
    {% else %}
    needs_additional_args = command_string == "scan" || command_string == "create" || command_string == "remote" || command_string == "clone" || command_string == "issues"
    {% end %}
    if needs_additional_args
      command.execute(repositories, repo_name, additional_args)
    else
      command.execute(repositories, repo_name)
    end
  rescue e : GitError
    Utils.print_error("❌ Error: #{e.message}")
    exit(1)
  end
end
