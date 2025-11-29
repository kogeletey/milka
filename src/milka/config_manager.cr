require "toml"
require "../milka/types/repository_info"
require "../milka/types/mise_config"
require "../milka/types/git_error"
require "./utils"

class ConfigManager
  def self.load_mise_config(path : String) : MiseConfig
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
            source = repo_hash["source"]?.try(&.as_s) || "git"

            repositories << RepositoryInfo.new(name, url, branch, commit, source)
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
              source = repo_hash["source"]?.try(&.as_s) || "git"

              repositories << RepositoryInfo.new(name, url, branch, commit, source)
            end
          else
            # It's a single object
            repo_hash = repo_data.as_h
            name = repo_hash["dir"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
            url = repo_hash["remote"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
            branch = repo_hash["branch"]?.try(&.as_s) || "main"
            commit = repo_hash["commit"]?.try(&.as_s) || ""
            source = repo_hash["source"]?.try(&.as_s) || "git"

            repositories << RepositoryInfo.new(name, url, branch, commit, source)
          end
        else
          raise GitError.config_file_invalid("Unexpected 'repo' data type: #{repo_data.class}")
        end
      end
    rescue e : TOML::ParseException
      raise GitError.config_file_invalid("Invalid TOML format: #{e.message}")
    end

    if repositories.empty?
      Utils.print_warning("No repositories found in config. Ensure .meta/reps.toml uses [[repo]] format with 'dir' and 'remote' keys.")
    end

    MiseConfig.new(repositories, "main", nil)
  rescue e : File::NotFoundError
    raise GitError.config_file_not_found("Configuration file not found at: #{path}")
  end

  def self.get_git_remote_info(git_dir : String) : String?
    begin
      # Execute git remote -v to get the remote URLs
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

  def self.get_git_branch(git_dir : String) : String
    begin
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
      else
        # Check if the error is because HEAD doesn't exist (no commits yet)
        stderr_output = stderr_builder.to_s
        if stderr_output.includes?("HEAD") && stderr_output.includes?("unknown revision")
          # If HEAD doesn't exist, default to main
          return "main"
        end
      end
    rescue
      # If there's an error, return default branch
    end

    "main" # Default branch
  end

  def self.repo_exists_in_config(config_path : String, dir_name : String) : Bool
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
        else
          repo_hash = repo_data.as_h
          existing_dir = repo_hash["dir"]?.try(&.as_s)
          return true if existing_dir == dir_name
        end
      end
    rescue
      # If there's an error parsing the config, return false
    end

    false
  end

  def self.add_git_repo_to_config(config_path : String, dir_name : String, remote_url : String, branch : String, source : String = "git")
    # Create the directory if it doesn't exist
    config_dir = File.dirname(config_path)
    Dir.mkdir_p(config_dir) unless File.directory?(config_dir)

    # Check if the repository already exists in the config
    return if repo_exists_in_config(config_path, dir_name)

    # Format the entry in TOML format
    new_entry = "\n[[repo]]\n"
    new_entry += "dir = '#{dir_name}'\n"
    new_entry += "remote = '#{remote_url}'\n"
    new_entry += "branch = '#{branch}'\n"
    new_entry += "source = '#{source}'\n\n" if source != "git"

    # Append the new entry to the config file
    File.open(config_path, "a") do |file|
      file.puts(new_entry)
    end
  end

  def self.scan_git_directories(root_path : String = ".") : Array(String)
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
end
