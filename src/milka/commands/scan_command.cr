require "../../milka"
require "../utils"
require "../repository_utils"

class ScanCommand
  def initialize(@config_path : String)
  end

  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
    # Handle the scan command separately - it doesn't require existing config
    RepositoryUtils.scan_and_add_git_repos(@config_path)
  end
end