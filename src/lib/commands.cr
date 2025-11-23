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
  when "scan"
    :scan
  when "init"
    :init
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
    exit(0)
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

  # Initialize repositories variable
  repositories = [] of RepositoryInfo

  # Load configuration for commands that need it (not for scan or init)
  if command != :scan && command != :init
    begin
      config = load_mise_config(config_path)
      print_info("Loaded #{config.repositories.size} repositories")
      repositories = config.repositories
    rescue e : GitError
      print_error("❌ Error: #{e.message}")
      exit(1)
    end

    # If no repos loaded, exit early (for commands that need config)
    if repositories.empty?
      print_error("No repositories available to process. Check the warning above and your config file.")
      exit(1)
    end

    # Override branch if specified
    if branch_override
      repositories = repositories.map do |repo|
        RepositoryInfo.new(repo.name, repo.url, branch_override, repo.latest_commit)
      end
    end
  end

  git_manager = GitManager.new

  begin
    case command
    when :scan
      # Handle the scan command separately - it doesn't require existing config
      scan_and_add_git_repos(config_path)
    when :init
      # Handle the init command - creates initial configuration
      init_config(config_path)
    else
      # For other commands, we need the configuration
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
    end
  rescue e : GitError
    print_error("❌ Error: #{e.message}")
    exit(1)
  end
end