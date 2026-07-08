require "./base_command"

class CloneCommand < BaseCommand
  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil, additional_args : Array(String) = [] of String)
    unless repositories
      raise GitError.config_file_invalid("No repositories provided to clone command")
    end

    if repo_name
      # Check if repo_name is a URL (contains http://, https://, or git@)
      if repo_name.starts_with?("http://") || repo_name.starts_with?("https://") || repo_name.starts_with?("git@")
        # Handle case: milka clone <URL> [custom_dir_name]
        if additional_args.empty?
          # No custom name provided, use name from URL
          clone_from_url(repo_name, nil, repositories)
        else
          # Custom name provided as first additional arg
          custom_name = additional_args[0]
          clone_from_url(repo_name, custom_name, repositories)
        end
      elsif additional_args.size == 1 && (additional_args[0].starts_with?("http://") || additional_args[0].starts_with?("https://") || additional_args[0].starts_with?("git@"))
        # Handle case: milka clone <custom_dir_name> <URL>
        url = additional_args[0]
        custom_name = repo_name
        clone_from_url(url, custom_name, repositories)
      else
        # This is a repo name from the config file
        repo = Utils.find_repository_in(repositories.not_nil!, named: repo_name)
        unless repo
          Utils.print_error("✗ Error: Repository '#{repo_name}' not found in configuration")
          exit(1)
        end

        git_manager.clone_repository(repo)
      end
    else
      git_manager.process_all_repositories(repositories, "clone")
    end
  end

  private def clone_from_url(url : String, custom_name : String?, existing_repositories : Array(RepositoryInfo))
    # Determine the directory name to use
    repo_name = if custom_name
                 custom_name
               else
                 extract_repo_name_from_url(url)
               end

    # Determine the branch to use
    branch = @branch_override || "main"

    # Determine the source type based on use_subtree flag
    source_type = @use_subtree ? "git+subtree" : "git"

    # For subtree operations, ensure we're in a git repository
    if source_type == "git+subtree"
      unless is_current_directory_git_repo?
        Utils.print_error("✗ Error: Subtree operations require the current directory to be a git repository")
        exit(1)
      end
    end

    # Check if repository already exists in config to avoid duplicates
    existing_repo = Utils.find_repository_in(existing_repositories, named: repo_name)
    if existing_repo
      Utils.print_warning("Repository '#{repo_name}' already exists in configuration, skipping.")
      return
    end

    # Create temporary RepositoryInfo for cloning
    temp_repo = RepositoryInfo.new(repo_name, url, branch, "", source_type)

    # Clone the repository
    git_manager.clone_repository(temp_repo)

    # Add the newly cloned repository to the configuration file
    begin
      ConfigManager.add_git_repo_to_config(@config_path, repo_name, url, branch, source_type)
      Utils.print_info("✓ Added '#{repo_name}' to #{@config_path}")
    rescue e
      Utils.print_error("! Warning: Failed to add '#{repo_name}' to config: #{e.message}")
    end
  end

  private def is_current_directory_git_repo? : Bool
    # Check if current directory has a .git folder or is inside a git repo
    current_dir = Dir.current
    git_path = File.join(current_dir, ".git")
    File.directory?(git_path) || git_repo_exists_in_parent_dirs?(current_dir)
  end

  private def git_repo_exists_in_parent_dirs?(path : String) : Bool
    # Check if we're inside a git repository by looking up the directory tree
    absolute_path = File.expand_path(path)

    # Try git command to see if we're in a git repo
    begin
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["rev-parse", "--git-dir"],
        output: stdout_builder,
        error: stderr_builder,
        chdir: absolute_path
      )

      return result.success?
    rescue
      # If git command fails, return false
      return false
    end
  end

  private def extract_repo_name_from_url(url : String) : String
    # Remove trailing slashes
    clean_url = url.gsub(/\/$/, "")

    if clean_url.starts_with?("git@")
      # Handle SSH URLs like git@github.com:user/repo.git
      # Extract the part after the colon
      path_part = clean_url.split(":")[1]?
      if path_part
        # Extract the last part after the last slash
        name = File.basename(path_part, ".git")
        # Remove any query parameters or fragments
        name = name.split(/[?#]/)[0]
        return name
      end
    end

    # Handle HTTP/HTTPS URLs
    # Extract the last part after the last slash
    # Handle both .git ending and regular URLs
    name = File.basename(clean_url, ".git")

    # Remove any query parameters or fragments
    name = name.split(/[?#]/)[0]

    name
  end
end
