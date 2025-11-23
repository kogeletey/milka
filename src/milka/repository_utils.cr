require "../milka/types/repository_info"
require "../milka/types/git_error"
require "./utils"

class RepositoryUtils
  def self.scan_and_add_git_repos(config_path : String, root_path : String = ".")
    Utils.print_info("Scanning for git repositories in: #{root_path}")

    git_dirs = ConfigManager.scan_git_directories(root_path)

    if git_dirs.empty?
      Utils.print_warning("No git repositories found in: #{root_path}")
      return
    end

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
      ConfigManager.add_git_repo_to_config(config_path, dir_name, remote_url, branch)
      Utils.print_success("  Added #{dir_name} to config")
      added_count += 1
    end

    Utils.print_success("Scan completed! Added #{added_count} repositories to #{config_path}")
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