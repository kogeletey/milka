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

  # Load configuration for commands that need it (not for scan, create, or remote commands)
  if command_string != "scan" && command_string != "init" && command_string != "create" && command_string != "remote"
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
  end

  begin
    # Create the correct command with subtree flag
    command = CommandFactory.create_command(command_string, config_path, branch_override, use_subtree)

    unless command
      Utils.print_error("Error: Invalid command '#{command_string}' after processing flags")
      Utils.print_usage
      exit(1)
    end

    if command_string == "scan" || command_string == "create" || command_string == "remote"
      command.execute(repositories, repo_name, additional_args)
    else
      command.execute(repositories, repo_name)
    end
  rescue e : GitError
    Utils.print_error("❌ Error: #{e.message}")
    exit(1)
  end
end
