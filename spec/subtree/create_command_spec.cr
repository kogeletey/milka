require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"
require "../../src/milka/types/mise_config"
require "../../src/milka/types/git_error"
require "../../src/milka/commands"
require "../../src/milka/git_operations"
require "../../src/milka/utils"
require "../../src/milka/config_manager"
require "../../src/milka/repository_utils"
require "../../src/milka/commands/scan_command"
require "../../src/milka/commands/create_command"

# Create temporary directory for test isolation
CREATE_CMD_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_create_command_spec_#{Time.local.to_unix}")

describe "CreateCommand" do
  before_all do
    Dir.mkdir_p(CREATE_CMD_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(CREATE_CMD_SPEC_TEMP_DIR)
      FileUtils.rm_rf(CREATE_CMD_SPEC_TEMP_DIR)
    end
  end

  it "should create new git repository in new directory" do
    temp_dir = File.join(CREATE_CMD_SPEC_TEMP_DIR, "create_new_test")
    Dir.mkdir_p(temp_dir)
    Dir.cd(temp_dir) do
      config_path = File.join(temp_dir, "reps.toml")

      # Create command instance
      command = CreateCommand.new(config_path, nil, false)
      command.execute(nil, "new_repo")

      # Check if directory and git repo were created
      new_repo_path = File.join(temp_dir, "new_repo")
      File.directory?(new_repo_path).should be_true

      git_path = File.join(new_repo_path, ".git")
      File.directory?(git_path).should be_true

      # Check config file was created with git source (default, so no explicit source field)
      File.exists?(config_path).should be_true
      config_content = File.read(config_path)
      config_content.includes?("dir = 'new_repo'").should be_true
      config_content.includes?("source = 'git+subtree'").should be_false # should not have subtree source
    end
  end

  it "should create subtree repository in existing directory when --subtree flag is used" do
    temp_dir = File.join(CREATE_CMD_SPEC_TEMP_DIR, "create_subtree_test")
    Dir.mkdir_p(temp_dir)
    Dir.cd(temp_dir) do
      config_path = File.join(temp_dir, "reps.toml")

      # Create an existing directory
      existing_dir = File.join(temp_dir, "existing_repo")
      Dir.mkdir_p(existing_dir)

      # Create command instance with subtree flag
      command = CreateCommand.new(config_path, nil, true)
      command.execute(nil, "existing_repo")

      # Check if git was initialized in the existing directory
      git_path = File.join(existing_dir, ".git")
      File.directory?(git_path).should be_true

      # Check config file was created with subtree source
      config_content = File.read(config_path)
      config_content.includes?("dir = 'existing_repo'").should be_true
      config_content.includes?("source = 'git+subtree'").should be_true
    end
  end

  it "should handle existing git repository when using subtree flag" do
    temp_dir = File.join(CREATE_CMD_SPEC_TEMP_DIR, "create_existing_git_test")
    Dir.mkdir_p(temp_dir)
    Dir.cd(temp_dir) do
      config_path = File.join(temp_dir, "reps.toml")

      # Create an existing git directory
      existing_git_dir = File.join(temp_dir, "git_repo")
      Dir.mkdir_p(existing_git_dir)
      Process.run("git", ["init"], chdir: existing_git_dir)

      # Create command instance with subtree flag
      command = CreateCommand.new(config_path, nil, true)
      command.execute(nil, "git_repo")

      # Check that it's still a git repo
      git_path = File.join(existing_git_dir, ".git")
      File.directory?(git_path).should be_true

      # Check config file was created with subtree source
      config_content = File.read(config_path)
      config_content.includes?("dir = 'git_repo'").should be_true
      config_content.includes?("source = 'git+subtree'").should be_true
    end
  end
end