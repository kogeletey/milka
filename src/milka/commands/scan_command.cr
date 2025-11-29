require "../../milka/types/repository_info"
require "../../milka/types/git_error"
require "../utils"
require "../repository_utils"

class ScanCommand
  def initialize(@config_path : String, @branch_override : String? = nil, @use_subtree : Bool = false)
  end

  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
    # Handle the scan command separately - it doesn't require existing config
    RepositoryUtils.scan_and_add_git_repos(@config_path, @use_subtree)
  end
end