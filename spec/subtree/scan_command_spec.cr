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

# Create temporary directory for test isolation
SCAN_CMD_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_scan_command_spec_#{Time.local.to_unix}")

describe "scan command with subtree flag" do
  before_all do
    Dir.mkdir_p(SCAN_CMD_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(SCAN_CMD_SPEC_TEMP_DIR)
      FileUtils.rm_rf(SCAN_CMD_SPEC_TEMP_DIR)
    end
  end

  it "should add existing git repos with subtree source when using --subtree flag" do
    temp_dir = File.join(SCAN_CMD_SPEC_TEMP_DIR, "scan_subtree_existing")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create an existing git repo inside temp_dir
    git_repo_dir = File.join(temp_dir, "existing_repo")
    Dir.mkdir_p(git_repo_dir)
    Process.run("git", ["init"], chdir: git_repo_dir)
    Process.run("git", ["remote", "add", "origin", "https://example.com/test/repo.git"], chdir: git_repo_dir)

    # Test the RepositoryUtils directly to scan the specific temp_dir
    RepositoryUtils.scan_and_add_git_repos(config_path, true, temp_dir)

    # Check config file contents
    config_content = File.read(config_path)
    config_content.includes?("source = 'git+subtree'").should be_true
    config_content.includes?("dir = 'existing_repo'").should be_true
  end

  it "should initialize git in non-git directories when using --subtree flag" do
    temp_dir = File.join(SCAN_CMD_SPEC_TEMP_DIR, "scan_non_git")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create a non-git directory
    non_git_dir = File.join(temp_dir, "new_dir")
    Dir.mkdir_p(non_git_dir)

    # Test the RepositoryUtils directly to scan the specific temp_dir
    RepositoryUtils.scan_and_add_git_repos(config_path, true, temp_dir)

    # Check if git was initialized
    git_dir = File.join(non_git_dir, ".git")
    File.directory?(git_dir).should be_true

    # Check config file has subtree source
    config_content = File.read(config_path)
    config_content.includes?("source = 'git+subtree'").should be_true
  end

  it "should not initialize git when not using subtree flag" do
    temp_dir = File.join(SCAN_CMD_SPEC_TEMP_DIR, "scan_no_subtree")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create a non-git directory
    non_git_dir = File.join(temp_dir, "new_dir")
    Dir.mkdir_p(non_git_dir)

    # Test the RepositoryUtils directly to scan the specific temp_dir
    RepositoryUtils.scan_and_add_git_repos(config_path, false, temp_dir)

    # Check that git was NOT initialized
    git_dir = File.join(non_git_dir, ".git")
    File.directory?(git_dir).should be_false
  end

  it "should add both git and non-git repos when using --subtree flag" do
    temp_dir = File.join(SCAN_CMD_SPEC_TEMP_DIR, "scan_mixed")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create an existing git repo
    git_repo_dir = File.join(temp_dir, "git_repo")
    Dir.mkdir_p(git_repo_dir)
    Process.run("git", ["init"], chdir: git_repo_dir)
    Process.run("git", ["remote", "add", "origin", "https://example.com/test/repo.git"], chdir: git_repo_dir)

    # Create a non-git directory
    non_git_dir = File.join(temp_dir, "new_repo")
    Dir.mkdir_p(non_git_dir)

    # Test the RepositoryUtils directly to scan the specific temp_dir
    RepositoryUtils.scan_and_add_git_repos(config_path, true, temp_dir)

    # Check config has both repos with subtree source
    config_content = File.read(config_path)
    config_content.scan(/source = 'git\+subtree'/).size.should eq(2) # both repos should have subtree source
  end

  it "should use default source for non-subtree scan" do
    temp_dir = File.join(SCAN_CMD_SPEC_TEMP_DIR, "scan_default")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create an existing git repo with remote
    git_repo_dir = File.join(temp_dir, "git_repo")
    Dir.mkdir_p(git_repo_dir)
    Process.run("git", ["init"], chdir: git_repo_dir)
    Process.run("git", ["remote", "add", "origin", "https://example.com/test/repo.git"], chdir: git_repo_dir)

    # Test the RepositoryUtils directly to scan the specific temp_dir
    RepositoryUtils.scan_and_add_git_repos(config_path, false, temp_dir)

    # Check config has default source (no source field since default is "git")
    config_content = File.read(config_path)
    config_content.includes?("source = 'git'").should be_false # default shouldn't be written
  end
end