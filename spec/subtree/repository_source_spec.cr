require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"
require "../../src/milka/types/mise_config"
require "../../src/milka/config_manager"

# Create temporary directory for test isolation
REPO_SOURCE_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_repository_source_spec_#{Time.local.to_unix}")

describe "repository source configuration" do
  before_all do
    Dir.mkdir_p(REPO_SOURCE_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(REPO_SOURCE_SPEC_TEMP_DIR)
      FileUtils.rm_rf(REPO_SOURCE_SPEC_TEMP_DIR)
    end
  end

  it "should parse source field from config" do
    toml_content = <<-'TOML'
      [[repo]]
      dir = 'test_repo'
      remote = 'https://example.com/test.git'
      source = 'git+subtree'
    TOML

    config_path = File.join(REPO_SOURCE_SPEC_TEMP_DIR, "source_config.toml")
    File.write(config_path, toml_content)
    config = ConfigManager.load_mise_config(config_path)

    config.repositories.size.should eq(1)
    config.repositories[0].source.should eq("git+subtree")
  end

  it "should default source to git when not specified" do
    toml_content = <<-'TOML'
      [[repo]]
      dir = 'test_repo'
      remote = 'https://example.com/test.git'
    TOML

    config_path = File.join(REPO_SOURCE_SPEC_TEMP_DIR, "default_source.toml")
    File.write(config_path, toml_content)
    config = ConfigManager.load_mise_config(config_path)

    config.repositories.size.should eq(1)
    config.repositories[0].source.should eq("git")
  end

  it "should handle mixed source types in config" do
    toml_content = <<-'TOML'
      [[repo]]
      dir = 'normal_repo'
      remote = 'https://example.com/normal.git'
      source = 'git'

      [[repo]]
      dir = 'subtree_repo'
      remote = 'https://example.com/subtree.git'
      source = 'git+subtree'
    TOML

    config_path = File.join(REPO_SOURCE_SPEC_TEMP_DIR, "mixed_sources.toml")
    File.write(config_path, toml_content)
    config = ConfigManager.load_mise_config(config_path)

    config.repositories.size.should eq(2)
    normal_repo = config.repositories.find { |r| r.name == "normal_repo" }
    normal_repo.should_not be_nil
    normal_repo.not_nil!.source.should eq("git")

    subtree_repo = config.repositories.find { |r| r.name == "subtree_repo" }
    subtree_repo.should_not be_nil
    subtree_repo.not_nil!.source.should eq("git+subtree")
  end
end