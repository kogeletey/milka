require "uuid"
require "./types/repository_info"
require "./types/git_error"
require "./git_operations"
require "./utils"

# Git Subtree Operations Manager
class GitSubtreeManager
  def add_subtree(repo : RepositoryInfo, prefix : String)
    current_dir = Dir.current

    spinner_id = start_spinner("Adding subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "add", "--prefix", prefix, repo.url, repo.branch, "--squash"], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_add_failed("Failed to add subtree from #{repo.url} to #{prefix}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def pull_subtree(repo : RepositoryInfo, prefix : String)
    current_dir = Dir.current

    spinner_id = start_spinner("Pulling subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "pull", "--prefix", prefix, repo.url, repo.branch, "--squash"], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_pull_failed("Failed to pull subtree from #{repo.url}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def push_subtree(repo : RepositoryInfo, prefix : String)
    current_dir = Dir.current

    spinner_id = start_spinner("Pushing subtree #{repo.name}")
    begin
      result = run_git_command("git", ["subtree", "push", "--prefix", prefix, repo.url, repo.branch], chdir: current_dir, spinner_id: spinner_id)

      unless result[:success]
        check_authentication_error(result[:stderr], repo.url, repo.name)

        raise GitError.subtree_push_failed("Failed to push subtree to #{repo.url}")
      end
    rescue e
      stop_spinner(spinner_id, success: false)
      raise e
    end
  end

  def process_subtree_repositories(repositories : Array(RepositoryInfo), command : String, prefix_mapping : Hash(String, String))
    repositories.each_with_index do |repo, index|
      prefix = prefix_mapping[repo.name]?
      unless prefix
        Utils.print_warning("No prefix mapping found for repository #{repo.name}, skipping...")
        next
      end

      action = command.capitalize
      Utils.print_info("[#{index}/#{repositories.size}] #{action} subtree #{repo.name} -> #{prefix}")
      case command
      when "add"
        add_subtree(repo, prefix)
      when "pull"
        pull_subtree(repo, prefix)
      when "push"
        push_subtree(repo, prefix)
      end
    end
  end
end