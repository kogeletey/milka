require "./commands/clone_command"
require "./commands/fetch_command"
require "./commands/pull_command"
require "./commands/push_command"
require "./commands/scan_command"
require "./commands/create_command"
require "./commands/remote_command"
require "./commands/github_command"

class CommandFactory
  def self.create_command(command_string : String, config_path : String, branch_override : String? = nil, use_subtree : Bool = false)
    case command_string
    when "clone"
      CloneCommand.new(config_path, branch_override)
    when "fetch"
      FetchCommand.new(config_path, branch_override)
    when "pull"
      PullCommand.new(config_path, branch_override)
    when "push"
      PushCommand.new(config_path, branch_override)
    when "scan"
      ScanCommand.new(config_path, branch_override, use_subtree)
    when "create"
      CreateCommand.new(config_path, branch_override, use_subtree)
    when "remote"
      RemoteCommand.new(config_path, branch_override)
    when "github"
      GithubCommand.new(config_path, branch_override, use_subtree)
    else
      nil
    end
  end
end
