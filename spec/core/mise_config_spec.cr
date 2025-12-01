require "spec"
require "file_utils"
require "../../src/milka/types/mise_config"
require "../../src/milka/types/repository_info"

# Create temporary directory for test isolation
MISE_CONFIG_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_mise_config_spec_#{Time.local.to_unix}")

describe "MiseConfig" do
  before_all do
    Dir.mkdir_p(MISE_CONFIG_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(MISE_CONFIG_SPEC_TEMP_DIR)
      FileUtils.rm_rf(MISE_CONFIG_SPEC_TEMP_DIR)
    end
  end

  it "initializes with repositories" do
    repos = [RepositoryInfo.new("repo1", "url1")]
    config = MiseConfig.new(repos, "main", nil)
    config.repositories.should eq(repos)
    config.default_branch.should eq("main")
    config.env.should be_nil
  end
end