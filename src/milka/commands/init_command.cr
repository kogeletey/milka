require "../../milka/types/repository_info"
require "../../milka/types/git_error"
require "../utils"
require "../repository_utils"

class InitCommand
  def initialize(@config_path : String)
  end

  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil)
    # Handle the init command - creates initial configuration
    RepositoryUtils.init_config(@config_path)
  end
end