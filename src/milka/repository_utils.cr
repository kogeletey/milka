require "../milka/types/repository_info"
require "../milka/types/git_error"
require "./utils"

class RepositoryUtils
  def self.scan_and_add_git_repos(config_path : String, use_subtree : Bool = false, root_path : String = ".")
    Utils.print_info("Scanning for git repositories in: #{root_path}")

    git_dirs = ConfigManager.scan_git_directories(root_path)

    Utils.print_info("Found #{git_dirs.size} git repositories")

    added_count = 0
    git_dirs.each do |git_dir|
      dir_name = File.basename(git_dir)

      Utils.print_info("Checking git repository: #{dir_name}")

      # Get the remote URL
      remote_url = ConfigManager.get_git_remote_info(git_dir)
      if remote_url.nil?
        Utils.print_warning("  No remote found for #{dir_name}, skipping...")
        next
      end

      # Get the current branch
      branch = ConfigManager.get_git_branch(git_dir)

      Utils.print_info("  Remote: #{remote_url}")
      Utils.print_info("  Branch: #{branch}")

      # Add to config if not already present
      source = use_subtree ? "git+subtree" : "git"
      ConfigManager.add_git_repo_to_config(config_path, dir_name, remote_url, branch, source)
      Utils.print_success("  Added #{dir_name} to config#{use_subtree ? " (with git+subtree source)" : ""}")
      added_count += 1
    end

    # If using subtree flag, also scan for non-git directories and initialize them as git repos
    if use_subtree
      Utils.print_info("Looking for non-git directories to initialize (for subtree use)...")
      non_git_dirs = scan_non_git_directories(root_path)

      if non_git_dirs.empty?
        Utils.print_info("No non-git directories found in: #{root_path}")
      else
        Utils.print_info("Found #{non_git_dirs.size} non-git directories")

        non_git_dirs.each do |dir_path|
          dir_name = File.basename(dir_path)

          Utils.print_info("Initializing git in directory: #{dir_name}")

          # Initialize git repository in the directory
          begin
            result = run_git_command("git", ["init"], chdir: dir_path)

            if result[:success]
              Utils.print_success("  Initialized git repository in #{dir_name}")

              # Add to config with subtree source
              # Use a default remote that can be changed later
              remote_url = "https://github.com/example/#{dir_name}.git"  # Placeholder
              branch = "main"

              ConfigManager.add_git_repo_to_config(config_path, dir_name, remote_url, branch, "git+subtree")
              Utils.print_success("  Added #{dir_name} to config (with git+subtree source)")
              added_count += 1
            else
              Utils.print_error("  Failed to initialize git in #{dir_name}")
            end
          rescue e
            Utils.print_error("  Error initializing git in #{dir_name}: #{e.message}")
          end
        end
      end
    end

    Utils.print_success("Scan completed! Added #{added_count} repositories to #{config_path}")
  end

  # Helper method to scan for non-git directories
  private def self.scan_non_git_directories(root_path : String = ".") : Array(String)
    non_git_directories = [] of String

    Dir.glob("#{root_path}/*").each do |path|
      next unless File.directory?(path)

      # Check if it already has a .git directory
      git_path = File.join(path, ".git")
      unless File.directory?(git_path)
        # This is a non-git directory, add it to the list
        non_git_directories << path
      end
    end

    non_git_directories
  end

  # Helper method to run git commands with consistent error handling
  private def self.run_git_command(cmd : String, args : Array(String), chdir : String? = nil)
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
      success: success,
      exit_code: result.exit_code,
      stdout: stdout_output,
      stderr: stderr_output
    }
  end

  def self.init_config(config_path : String)
    # Check if the config file already exists
    if File.exists?(config_path)
      Utils.print_error("❌ Error: Configuration file already exists at: #{config_path}")
      Utils.print_info("💡 To create a new configuration, remove the existing file first or use a different path.")
      Utils.print_info("   Use: milka --config <new_path> init")
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

    Utils.print_success("✅ Configuration file created at: #{config_path}")
    Utils.print_info("💡 Edit #{config_path} to add your repositories:")
    Utils.print_info("   - Replace 'my-project' with your local directory name")
    Utils.print_info("   - Replace 'https://github.com/username/my-project.git' with your repository URL")
    Utils.print_info("   - Set the appropriate branch (default: 'main')")
    Utils.print_info("   - Add more repositories by duplicating the [[repo]] block")
  end
end