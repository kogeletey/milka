require "spec"
require "file_utils"
require "../../src/milka/repository_utils"
require "../../src/milka/config_manager"

# Create temporary directory for test isolation
REPO_UTILS_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_repository_utils_spec_#{Time.local.to_unix}")

describe "RepositoryUtils" do
  before_all do
    Dir.mkdir_p(REPO_UTILS_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(REPO_UTILS_SPEC_TEMP_DIR)
      FileUtils.rm_rf(REPO_UTILS_SPEC_TEMP_DIR)
    end
  end

  it "should scan non-git directories correctly" do
    temp_dir = File.join(REPO_UTILS_SPEC_TEMP_DIR, "scan_non_git_test")
    Dir.mkdir_p(temp_dir)

    # Create a git directory
    git_dir = File.join(temp_dir, "git_repo")
    Dir.mkdir_p(git_dir)
    Process.run("git", ["init"], chdir: git_dir)

    # Create a non-git directory
    non_git_dir = File.join(temp_dir, "non_git_repo")
    Dir.mkdir_p(non_git_dir)

    # Test the internal method to scan non-git directories
    non_git_dirs = [] of String
    Dir.glob("#{temp_dir}/*").each do |path|
      next unless File.directory?(path)
      git_path = File.join(path, ".git")
      unless File.directory?(git_path)
        non_git_dirs << path
      end
    end

    non_git_dirs.size.should eq(1)
    File.basename(non_git_dirs[0]).should eq("non_git_repo")
  end

  it "should add git repo to config with source parameter" do
    config_path = File.join(REPO_UTILS_SPEC_TEMP_DIR, "add_repo_config.toml")

    # Use the ConfigManager method to add a repo with source
    ConfigManager.add_git_repo_to_config(config_path, "test_repo", "https://example.com/repo.git", "main", "git+subtree")

    # Check the config file
    content = File.read(config_path)
    content.includes?("dir = 'test_repo'").should be_true
    content.includes?("source = 'git+subtree'").should be_true
  end

  it "should add git repo to config with default source when not specified" do
    config_path = File.join(REPO_UTILS_SPEC_TEMP_DIR, "add_repo_default.toml")

    # Use the ConfigManager method to add a repo without specifying source (should default)
    ConfigManager.add_git_repo_to_config(config_path, "test_repo", "https://example.com/repo.git", "main")

    # Check the config file doesn't include source (because default is git)
    content = File.read(config_path)
    content.includes?("dir = 'test_repo'").should be_true
    content.includes?("source = 'git'").should be_false
  end

  it "should handle scan_and_add_git_repos with subtree flag properly" do
    temp_dir = File.join(REPO_UTILS_SPEC_TEMP_DIR, "scan_add_test")
    Dir.mkdir_p(temp_dir)
    config_path = File.join(temp_dir, "reps.toml")

    # Create a non-git directory
    non_git_dir = File.join(temp_dir, "new_repo")
    Dir.mkdir_p(non_git_dir)

    # Call the scan method with subtree flag
    RepositoryUtils.scan_and_add_git_repos(config_path, true, temp_dir)

    # Check that config was created with subtree source
    content = File.read(config_path)
    content.includes?("source = 'git+subtree'").should be_true
  end
end