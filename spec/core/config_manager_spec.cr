require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"
require "../../src/milka/types/mise_config"
require "../../src/milka/types/git_error"
require "../../src/milka/config_manager"

# Create temporary directory for test isolation
CONFIG_MANAGER_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_config_manager_spec_#{Time.local.to_unix}")

describe "ConfigManager" do
  before_all do
    Dir.mkdir_p(CONFIG_MANAGER_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(CONFIG_MANAGER_SPEC_TEMP_DIR)
      FileUtils.rm_rf(CONFIG_MANAGER_SPEC_TEMP_DIR)
    end
  end

  describe "load_mise_config" do
    it "loads valid TOML configuration" do
      toml_content = <<-'TOML'
        [[repo]]
        dir = 'my-repo'
        remote = 'https://github.com/example/my-repo'
        branch = 'main'

        [[repo]]
        dir = 'frontend'
        remote = 'https://github.com/example/frontend'
        TOML

      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "test_config.toml")
      File.write(config_path, toml_content)

      config = load_mise_config(config_path)
      config.repositories.size.should eq(2)
      config.repositories[0].name.should eq("my-repo")
      config.repositories[0].url.should eq("https://github.com/example/my-repo")
      config.repositories[0].branch.should eq("main")
      config.repositories[1].name.should eq("frontend")
      config.repositories[1].url.should eq("https://github.com/example/frontend")
      config.repositories[1].branch.should eq("main")
    end

    it "handles empty file" do
      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "empty_config.toml")
      File.write(config_path, "")

      config = load_mise_config(config_path)
      config.repositories.size.should eq(0)
    end

    it "raises error for missing file" do
      expect_raises(GitError) do
        load_mise_config("/nonexistent.toml")
      end
    end

    it "handles configuration with commits" do
      toml_content = <<-'TOML'
        [[repo]]
        dir = 'repo-with-commit'
        remote = 'https://github.com/example/repo'
        branch = 'feature'
        commit = 'abc123'
        TOML

      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "commit_config.toml")
      File.write(config_path, toml_content)

      config = load_mise_config(config_path)
      config.repositories.size.should eq(1)
      config.repositories[0].name.should eq("repo-with-commit")
      config.repositories[0].latest_commit.should eq("abc123")
      config.repositories[0].branch.should eq("feature")
    end
  end

  describe "init_config" do
    it "creates config directory and file when it doesn't exist" do
      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "init_test", "reps.toml")

      init_config(config_path)

      File.exists?(config_path).should be_true

      content = File.read(config_path)
      content.should contain("# [[repo]]")
      content.should contain("# dir = 'project'")
      content.should contain("# remote = 'https://example.com/username/my-project.git'")
      content.should contain("# branch = 'develop'")
    end

    it "creates directory if it doesn't exist" do
      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "nonexistent_dir", "nested", "reps.toml")

      init_config(config_path)

      File.exists?(config_path).should be_true
      Dir.exists?(File.dirname(config_path)).should be_true
    end

    it "should raise GitError when config file already exists" do
      config_path = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "existing_config.toml")
      # Create an existing config file
      File.write(config_path, "[[repo]]\ndir = 'existing-repo'\nremote = 'http://example.com/repo.git'\n")

      expect_raises(GitError) do
        init_config(config_path)
      end
    end

    it "should create config file even if directory exists but config doesn't" do
      # Create a directory that exists but no config file inside
      test_dir = File.join(CONFIG_MANAGER_SPEC_TEMP_DIR, "test_dir")
      Dir.mkdir_p(test_dir) unless Dir.exists?(test_dir)
      # Add a dummy file to the directory to ensure it exists
      dummy_path = File.join(test_dir, "dummy.txt")
      File.write(dummy_path, "dummy content")

      config_path = File.join(test_dir, "reps.toml")

      # Verify that the config file doesn't exist yet
      File.exists?(config_path).should be_false

      # Now run init_config which should create the config file
      init_config(config_path)

      # Verify config file was created
      File.exists?(config_path).should be_true

      # Verify the content is correct
      content = File.read(config_path)
      content.should contain("# [[repo]]")
      content.should contain("# dir = 'project'")
    end
  end
end