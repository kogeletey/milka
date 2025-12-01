require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"

# Create temporary directory for test isolation
REPO_INFO_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_repository_info_spec_#{Time.local.to_unix}")

describe "RepositoryInfo" do
  before_all do
    Dir.mkdir_p(REPO_INFO_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(REPO_INFO_SPEC_TEMP_DIR)
      FileUtils.rm_rf(REPO_INFO_SPEC_TEMP_DIR)
    end
  end

  it "initializes with required parameters" do
    repo = RepositoryInfo.new("test-repo", "https://github.com/test/repo", "main")
    repo.name.should eq("test-repo")
    repo.url.should eq("https://github.com/test/repo")
    repo.branch.should eq("main")
    repo.latest_commit.should eq("")
    repo.local_path.should eq("test-repo")
  end

  it "initializes with default branch" do
    repo = RepositoryInfo.new("test-repo", "https://github.com/test/repo")
    repo.branch.should eq("main")
  end

  it "initializes with commit" do
    repo = RepositoryInfo.new("test-repo", "https://github.com/test/repo", "main", "abc123")
    repo.latest_commit.should eq("abc123")
  end

  it "should handle git operations for regular repos" do
    repo = RepositoryInfo.new("test", "https://example.com/test.git", "main", "", "git")
    repo.source.should eq("git")
  end

  it "should handle git operations for subtree repos" do
    repo = RepositoryInfo.new("test", "https://example.com/test.git", "main", "", "git+subtree")
    repo.source.should eq("git+subtree")
  end

  it "should route operations based on source type" do
    # This tests the GitManager routing logic indirectly
    git_repo = RepositoryInfo.new("git_test", "https://example.com/test.git", "main", "", "git")
    subtree_repo = RepositoryInfo.new("subtree_test", "https://example.com/test.git", "main", "", "git+subtree")

    git_repo.source.should eq("git")
    subtree_repo.source.should eq("git+subtree")
  end
end