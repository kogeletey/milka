require "./base_command"
require "../repository_utils"
require "../utils"
require "../config_manager"

class RemoteCommand < BaseCommand
  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil, additional_args : Array(String) = [] of String)
    # Check if repo_name is provided
    if repo_name.nil?
      Utils.print_error("❌ Error: Repository name is required for remote command")
      Utils.print_info("💡 Usage: milka remote <repo-name> [remote-url]")
      return
    end

    # Find the repository in the current directory
    repo_path = File.join(Dir.current, repo_name)

    unless File.directory?(repo_path)
      Utils.print_error("❌ Error: Directory #{repo_name} does not exist")
      return
    end

    # Check if it's a git repository
    git_path = File.join(repo_path, ".git")
    unless File.directory?(git_path)
      Utils.print_error("❌ Error: #{repo_name} is not a git repository")
      return
    end

    # Get remote URL from command line arguments or prompt user
    remote_url = ARGV.find { |arg| arg != "remote" && arg != repo_name }

    if remote_url.nil?
      Utils.print_error("❌ Error: Remote URL is required")
      Utils.print_info("💡 Usage: milka remote <repo-name> <remote-url>")
      return
    end

    # Validate if the URL is properly formatted
    unless valid_git_url?(remote_url)
      Utils.print_error("❌ Error: Invalid git URL format: #{remote_url}")
      Utils.print_info("💡 Valid formats: https://example.com/user/repo.git, git@github.com:user/repo.git")
      return
    end

    # Add the remote to the repository
    spinner_id = start_spinner("Adding remote to #{repo_name}")
    begin
      # Check if origin remote already exists
      existing_remote = check_existing_remote(repo_path)

      if existing_remote
        stop_spinner(spinner_id, success: false)
        Utils.print_warning("⚠️  Remote 'origin' already exists: #{existing_remote}")
        print("Do you want to overwrite it? (y/N): ")
        response = gets
        unless response.try(&.strip).try(&.downcase) == "y"
          Utils.print_info("Remote addition cancelled.")
          return
        end
        # Remove existing origin remote
        remove_result = run_git_command("git", ["remote", "remove", "origin"], chdir: repo_path)
        unless remove_result[:success]
          stop_spinner(spinner_id, success: false)
          Utils.print_error("❌ Failed to remove existing remote")
          return
        end
      end

      # Add the new remote
      result = run_git_command("git", ["remote", "add", "origin", remote_url], chdir: repo_path, spinner_id: spinner_id)

      if result[:success]
        stop_spinner(spinner_id, success: true)
        Utils.print_success("✅ Added remote 'origin' with URL: #{remote_url}")

        # Update the configuration file with the new remote URL if it exists in config
        update_config_with_remote(repo_name, remote_url)
      else
        stop_spinner(spinner_id, success: false)
        Utils.print_error("❌ Failed to add remote to #{repo_name}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      Utils.print_error("❌ Error adding remote: #{e.message}")
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

  private def update_config_with_remote(repo_name : String, remote_url : String)
    # Check if repo exists in config and update its remote
    begin
      config = ConfigManager.load_mise_config(@config_path)
      repo_exists = config.repositories.any? { |repo| repo.name == repo_name }

      if repo_exists
        # Read the entire config file
        content = File.read(@config_path)
        lines = content.lines

        # Find the repository entry and update the remote
        updated_lines = [] of String
        in_repo_block = false
        current_repo_name = ""

        lines.each do |line|
          if line.includes?("[[repo]]")
            in_repo_block = true
            updated_lines << line
            next
          end

          if in_repo_block
            if line.strip.starts_with?("dir =")
              # Extract the dir name to compare
              if line.match(/dir = ['"](.+)['"]/)
                current_repo_name = $1
              end
              updated_lines << line
            elsif line.strip.starts_with?("remote =") && current_repo_name == repo_name
              # Update the remote for this specific repo
              indent = line.match(/^(\s*)/)[1] # Preserve indentation
              updated_lines << "#{indent}remote = '#{remote_url}'\n"
              in_repo_block = false # Reset for next repo
            else
              updated_lines << line
              # When we encounter another [[repo]] or end of repo block, reset
              if line.strip.starts_with?("dir =") && current_repo_name != repo_name
                in_repo_block = false
              end
            end
          else
            updated_lines << line
          end
        end

        # Write updated content back to file
        File.write(@config_path, updated_lines.join(""))
        Utils.print_info("Updated #{repo_name} remote in config file")
      else
        Utils.print_info("#{repo_name} not found in config file, skipping config update")
      end
    rescue e
      Utils.print_error("Error updating config: #{e.message}")
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
end
