require "./base_command"
require "../repository_utils"
require "../utils"
require "../config_manager"

class CreateCommand < BaseCommand
  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil, additional_args : Array(String) = [] of String)
    # For the create command, we don't need existing repositories from config
    # Instead, we'll create new git repositories based on the parameters

    if repo_name.nil?
      Utils.print_error("❌ Error: Repository name is required for create command")
      Utils.print_info("💡 Usage: milka create <repo-name> [remote-url]")
      return
    end

    remote_url = additional_args.first? # Get the optional remote URL from additional arguments

    repo_dir = repo_name
    current_dir = Dir.current
    absolute_path = File.join(current_dir, repo_dir)

    if File.exists?(absolute_path)
      # Check if it's already a git repository
      git_path = File.join(absolute_path, ".git")
      if File.directory?(git_path)
        # It's an existing git repository, handle as subtree if requested
        if @use_subtree
          create_subtree_repo(repo_dir, absolute_path, remote_url)
        else
          Utils.print_warning("Repository #{repo_dir} already exists as a git repository")
          # Still try to add remote if provided
          add_remote_if_needed(absolute_path, repo_dir, remote_url)
        end
      else
        # It's not a git repo, but exists as a directory
        if @use_subtree
          create_subtree_repo(repo_dir, absolute_path, remote_url)
        else
          Utils.print_error("❌ Error: Directory #{repo_dir} already exists but is not a git repository")
          Utils.print_info("💡 Use 'milka scan' to scan existing directories or initialize git manually first")
        end
      end
    else
      # Directory doesn't exist, create new git repository
      create_new_git_repo(repo_dir, absolute_path, remote_url)
    end
  end

  private def create_new_git_repo(repo_dir : String, absolute_path : String, remote_url : String? = nil)
    spinner_id = start_spinner("Creating git repository #{repo_dir}")
    begin
      Dir.mkdir_p(absolute_path)

      result = run_git_command("git", ["init"], chdir: absolute_path, spinner_id: spinner_id)

      if result[:success]
        stop_spinner(spinner_id, success: true)
        Utils.print_success("✅ Created new git repository in #{repo_dir}")

        # Add remote if provided
        if remote_url
          add_remote(absolute_path, repo_dir, remote_url)
        end

        # Add to configuration with git source
        config_dir = File.dirname(@config_path)
        Dir.mkdir_p(config_dir) unless File.directory?(config_dir)

        # Use the provided remote URL if available, otherwise empty string
        remote_url_for_config = remote_url || ""
        ConfigManager.add_git_repo_to_config(@config_path, repo_dir, remote_url_for_config, "main", "git")
        Utils.print_info("Added #{repo_dir} to configuration with source = 'git'")
      else
        stop_spinner(spinner_id, success: false)
        Utils.print_error("❌ Failed to initialize git repository in #{repo_dir}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      Utils.print_error("❌ Error creating git repository: #{e.message}")
    end
  end

  private def create_subtree_repo(repo_dir : String, absolute_path : String, remote_url : String? = nil)
    # For existing directories, make sure git is initialized
    spinner_id = start_spinner("Setting up subtree for #{repo_dir}")
    begin
      git_path = File.join(absolute_path, ".git")

      if File.directory?(git_path)
        # Already a git repo, just add to config with subtree source
        stop_spinner(spinner_id, success: true)
        Utils.print_success("✅ Repository #{repo_dir} is already a git repository")
      else
        # Initialize git in existing directory
        result = run_git_command("git", ["init"], chdir: absolute_path, spinner_id: spinner_id)

        if result[:success]
          stop_spinner(spinner_id, success: true)
          Utils.print_success("✅ Initialized git in #{repo_dir}")
        else
          stop_spinner(spinner_id, success: false)
          Utils.print_error("❌ Failed to initialize git in #{repo_dir}")
          return
        end
      end

      # Add remote if provided
      if remote_url
        add_remote(absolute_path, repo_dir, remote_url)
      end

      # Add to configuration with subtree source
      remote_url_for_config = remote_url || ""
      ConfigManager.add_git_repo_to_config(@config_path, repo_dir, remote_url_for_config, "main", "git+subtree")
      Utils.print_info("Added #{repo_dir} to configuration with source = 'git+subtree'")
    rescue e
      stop_spinner(spinner_id, success: false)
      Utils.print_error("❌ Error setting up subtree: #{e.message}")
    end
  end

  private def run_git_command(cmd : String, args : Array(String), chdir : String? = nil, spinner_id : String? = nil)
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

  private def add_remote(repo_path : String, repo_name : String, remote_url : String)
    # Validate if the URL is properly formatted
    unless valid_git_url?(remote_url)
      Utils.print_error("❌ Error: Invalid git URL format: #{remote_url}")
      Utils.print_info("💡 Valid formats: https://example.com/user/repo.git, git@github.com:user/repo.git")
      return
    end

    # Check if origin remote already exists
    existing_remote = check_existing_remote(repo_path)

    if existing_remote
      Utils.print_warning("⚠️  Remote 'origin' already exists: #{existing_remote}")
      # For the create command, we'll automatically overwrite if a remote is provided
      remove_result = run_git_command("git", ["remote", "remove", "origin"], chdir: repo_path)
      unless remove_result[:success]
        Utils.print_error("❌ Failed to remove existing remote")
        return
      end
    end

    # Add the new remote
    result = run_git_command("git", ["remote", "add", "origin", remote_url], chdir: repo_path)

    if result[:success]
      Utils.print_success("✅ Added remote 'origin' with URL: #{remote_url}")
    else
      Utils.print_error("❌ Failed to add remote to #{repo_name}")
    end
  end

  private def add_remote_if_needed(repo_path : String, repo_name : String, remote_url : String?)
    if remote_url
      add_remote(repo_path, repo_name, remote_url)
    end
  end

  private def valid_git_url?(url : String) : Bool
    # Basic validation for git URLs
    # Supports: https://example.com/user/repo.git, git@github.com:user/repo.git, etc.
    url.starts_with?("http://") ||
      url.starts_with?("https://") ||
      url.starts_with?("git@") ||
      url.ends_with?(".git")
  end

  private def check_existing_remote(repo_path : String) : String?
    # Check if a remote named 'origin' already exists
    stdout_builder = String::Builder.new
    stderr_builder = String::Builder.new

    result = Process.run(
      "git",
      ["remote", "get-url", "origin"],
      output: stdout_builder,
      error: stderr_builder,
      chdir: repo_path
    )

    if result.success?
      remote_url = stdout_builder.to_s.strip
      return remote_url unless remote_url.empty?
    end

    nil
  end
end
