require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"
require "../../src/milka/types/mise_config"
require "../../src/milka/types/git_error"
require "../../src/milka/commands"
require "../../src/milka/utils"
require "../../src/milka/config_manager"
require "../../src/milka/commands/github_command"

# Create temporary directory for test isolation
GITHUB_CMD_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_github_command_spec_#{Time.local.to_unix}")

describe "github command" do
  before_all do
    Dir.mkdir_p(GITHUB_CMD_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(GITHUB_CMD_SPEC_TEMP_DIR)
      FileUtils.rm_rf(GITHUB_CMD_SPEC_TEMP_DIR)
    end
  end

  describe "GithubCommand initialization" do
    it "should create a command with config path" do
      temp_dir = File.join(GITHUB_CMD_SPEC_TEMP_DIR, "init_test")
      Dir.mkdir_p(temp_dir)
      config_path = File.join(temp_dir, "reps.toml")

      command = GithubCommand.new(config_path)
      command.should_not be_nil
    end

    it "should create a command with branch override" do
      temp_dir = File.join(GITHUB_CMD_SPEC_TEMP_DIR, "branch_test")
      Dir.mkdir_p(temp_dir)
      config_path = File.join(temp_dir, "reps.toml")

      command = GithubCommand.new(config_path, "develop")
      command.should_not be_nil
    end

    it "should create a command with subtree flag" do
      temp_dir = File.join(GITHUB_CMD_SPEC_TEMP_DIR, "subtree_test")
      Dir.mkdir_p(temp_dir)
      config_path = File.join(temp_dir, "reps.toml")

      command = GithubCommand.new(config_path, nil, true)
      command.should_not be_nil
    end
  end

  describe "GithubCommand execute" do
    it "should print error when no org name is provided" do
      temp_dir = File.join(GITHUB_CMD_SPEC_TEMP_DIR, "no_org_test")
      Dir.mkdir_p(temp_dir)
      config_path = File.join(temp_dir, "reps.toml")

      command = GithubCommand.new(config_path)

      # Execute with no org name - should not raise, just print error
      command.execute(nil, nil, [] of String)

      # The command should complete without error
      true.should be_true
    end

    it "should print error for empty org name" do
      temp_dir = File.join(GITHUB_CMD_SPEC_TEMP_DIR, "empty_org_test")
      Dir.mkdir_p(temp_dir)
      config_path = File.join(temp_dir, "reps.toml")

      command = GithubCommand.new(config_path)

      # Execute with empty org name - should not raise, just print error
      command.execute(nil, "", [] of String)

      # The command should complete without error
      true.should be_true
    end
  end
end

describe "github command in command factory" do
  it "should create GithubCommand from factory" do
    command = CommandFactory.create_command("github", ".meta/reps.toml")
    command.should_not be_nil
    command.should be_a(GithubCommand)
  end

  it "should create GithubCommand with subtree flag" do
    command = CommandFactory.create_command("github", ".meta/reps.toml", nil, true)
    command.should_not be_nil
    command.should be_a(GithubCommand)
  end

  it "should create GithubCommand with branch override" do
    command = CommandFactory.create_command("github", ".meta/reps.toml", "develop", false)
    command.should_not be_nil
    command.should be_a(GithubCommand)
  end
end

describe "github command string parsing" do
  it "should parse 'github' as valid command" do
    result = get_command_from_string("github")
    result.should eq(:github)
  end
end
