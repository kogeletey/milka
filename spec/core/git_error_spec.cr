require "spec"
require "file_utils"
require "../../src/milka/types/git_error"

# Create temporary directory for test isolation
GIT_ERROR_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_git_error_spec_#{Time.local.to_unix}")

describe "GitError" do
  before_all do
    Dir.mkdir_p(GIT_ERROR_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(GIT_ERROR_SPEC_TEMP_DIR)
      FileUtils.rm_rf(GIT_ERROR_SPEC_TEMP_DIR)
    end
  end

  it "has various error types with proper messages" do
    GitError.clone_failed("test").message.should eq("Clone failed: test")
    GitError.fetch_failed("test").message.should eq("Fetch failed: test")
    GitError.pull_failed("test").message.should eq("Pull failed: test")
    GitError.push_failed("test").message.should eq("Push failed: test")
    GitError.config_file_not_found("test").message.should eq("Config file not found: test")
    GitError.config_file_invalid("test").message.should eq("Config file invalid: test")
    GitError.authentication_required("test").message.should eq(
      "Authentication required: test. Please provide a username/password or use a personal access token for private repositories."
    )
  end
end