require "./commands/clone_command"
require "./commands/fetch_command"
require "./commands/pull_command"
require "./commands/push_command"
require "./commands/scan_command"
require "./commands/init_command"

class CommandFactory
  def self.create_command(command_string : String, config_path : String, branch_override : String? = nil, use_subtree : Bool = false)
    case command_string
    when "clone"
      CloneCommand.new(config_path, branch_override, use_subtree)
    when "fetch"
      FetchCommand.new(config_path, branch_override, use_subtree)
    when "pull"
      PullCommand.new(config_path, branch_override, use_subtree)
    when "push"
      PushCommand.new(config_path, branch_override, use_subtree)
    when "scan"
      ScanCommand.new(config_path)
    when "init"
      InitCommand.new(config_path)
    else
      nil
    end
  end
end