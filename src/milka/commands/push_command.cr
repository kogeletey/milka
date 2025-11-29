require "./base_command"

class PushCommand < BaseCommand
  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
    unless repositories
      raise GitError.config_file_invalid("No repositories provided to push command")
    end

    if repo_name
      repo = Utils.find_repository_in(repositories.not_nil!, named: repo_name)
      unless repo
        Utils.print_error("❌ Error: Repository '#{repo_name}' not found in configuration")
        exit(1)
      end

      # If using subtree flag, only process if repo source is git+subtree
      if @use_subtree && repo.source != "git+subtree"
        Utils.print_warning("Repository '#{repo_name}' is not a subtree source, skipping.")
        return
      end

      git_manager.push_repository(repo)
    else
      # Filter repositories if using subtree flag
      filtered_repos = @use_subtree ? repositories.select { |repo| repo.source == "git+subtree" } : repositories
      if @use_subtree && filtered_repos.empty?
        Utils.print_warning("No repositories with source 'git+subtree' found")
        return
      end

      git_manager.process_all_repositories(filtered_repos, "push")
    end
  end
end