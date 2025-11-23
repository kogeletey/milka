require "../git_operations"
require "../utils"

# Base command class to be inherited by all commands
abstract class BaseCommand
  protected getter git_manager : GitManager
  protected getter config_path : String
  protected getter branch_override : String?

  def initialize(@config_path : String, @branch_override : String? = nil)
    @git_manager = GitManager.new
  end

  abstract def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
end