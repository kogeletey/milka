require "./base_command"

class PushCommand < BaseCommand
  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
    if repo_name
      repo = Utils.find_repository_in(repositories.not_nil!, named: repo_name)
      unless repo
        Utils.print_error("❌ Error: Repository '#{repo_name}' not found in configuration")
        exit(1)
      end
      git_manager.push_repository(repo)
    else
      git_manager.process_all_repositories(repositories.not_nil!, "push")
    end
  end
end