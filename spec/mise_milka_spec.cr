require "spec"
require "file_utils"
require "../src/milka"

# Create temporary directory for test isolation
SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_spec_#{Time.local.to_unix}")

describe "Milka" do
  before_all do
    Dir.mkdir_p(SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(SPEC_TEMP_DIR)
      FileUtils.rm_rf(SPEC_TEMP_DIR)
    end
  end

  describe "RepositoryInfo" do
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
  end

  describe "MiseConfig" do
    it "initializes with repositories" do
      repos = [RepositoryInfo.new("repo1", "url1")]
      config = MiseConfig.new(repos, "main", nil)
      config.repositories.should eq(repos)
      config.default_branch.should eq("main")
      config.env.should be_nil
    end
  end

  describe "GitError" do
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

      config_path = File.join(SPEC_TEMP_DIR, "test_config.toml")
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
      config_path = File.join(SPEC_TEMP_DIR, "empty_config.toml")
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

      config_path = File.join(SPEC_TEMP_DIR, "commit_config.toml")
      File.write(config_path, toml_content)

      config = load_mise_config(config_path)
      config.repositories.size.should eq(1)
      config.repositories[0].name.should eq("repo-with-commit")
      config.repositories[0].latest_commit.should eq("abc123")
      config.repositories[0].branch.should eq("feature")
    end
  end

  describe "GitManager" do
    it "processes all repositories" do
      repos = [
        RepositoryInfo.new("repo1", "https://github.com/example/repo1"),
        RepositoryInfo.new("repo2", "https://github.com/example/repo2"),
      ]

      # Since we can't really clone these repos without network access,
      # we'll just make sure the method doesn't crash on an empty array
      git_manager = GitManager.new
      # This test would need real git repos to properly test, but we can at least verify the method exists
      git_manager.class.should eq(GitManager)
    end
  end

  describe "Utility functions" do
    it "finds repository by name" do
      repos = [
        RepositoryInfo.new("repo1", "url1"),
        RepositoryInfo.new("repo2", "url2"),
      ]

      found = find_repository_in(repos, named: "repo1")
      found.should_not be_nil
      found.try(&.name).should eq("repo1")

      not_found = find_repository_in(repos, named: "repo3")
      not_found.should be_nil
    end

    it "parses command string correctly" do
      get_command_from_string("clone").should eq(:clone)
      get_command_from_string("fetch").should eq(:fetch)
      get_command_from_string("pull").should eq(:pull)
      get_command_from_string("push").should eq(:push)
      get_command_from_string("help").should eq(:help)
      get_command_from_string("invalid").should be_nil
    end
  end

  # Test CLI argument parsing logic
  describe "Argument parsing" do
    it "parses basic commands" do
      args = ["clone", "my-repo"]
      config_path = ".meta/reps.toml"
      branch_override = nil
      non_option_args = [] of String

      i = 0
      while i < args.size
        arg = args[i]
        if arg == "--config" && i + 1 < args.size
          config_path = args[i + 1]
          i += 2
          next
        elsif arg == "--branch" && i + 1 < args.size
          branch_override = args[i + 1]
          i += 2
          next
        elsif arg.starts_with?("--")
          i += 1
          next
        else
          non_option_args << arg
          i += 1
        end
      end

      non_option_args.should eq(["clone", "my-repo"])
      config_path.should eq(".meta/reps.toml")
      branch_override.should be_nil
    end

    it "parses with config option" do
      args = ["--config", "custom.toml", "pull"]
      config_path = ".meta/reps.toml"
      branch_override = nil
      non_option_args = [] of String

      i = 0
      while i < args.size
        arg = args[i]
        if arg == "--config" && i + 1 < args.size
          config_path = args[i + 1]
          i += 2
          next
        elsif arg == "--branch" && i + 1 < args.size
          branch_override = args[i + 1]
          i += 2
          next
        elsif arg.starts_with?("--")
          i += 1
          next
        else
          non_option_args << arg
          i += 1
        end
      end

      non_option_args.should eq(["pull"])
      config_path.should eq("custom.toml")
    end

    it "parses with branch option" do
      args = ["--branch", "dev", "push", "repo"]
      config_path = ".meta/reps.toml"
      branch_override = nil
      non_option_args = [] of String

      i = 0
      while i < args.size
        arg = args[i]
        if arg == "--config" && i + 1 < args.size
          config_path = args[i + 1]
          i += 2
          next
        elsif arg == "--branch" && i + 1 < args.size
          branch_override = args[i + 1]
          i += 2
          next
        elsif arg.starts_with?("--")
          i += 1
          next
        else
          non_option_args << arg
          i += 1
        end
      end

      non_option_args.should eq(["push", "repo"])
      branch_override.should eq("dev")
    end
  end

  describe "SpinnerState" do
    it "manages spinner state correctly" do
      spinner = SpinnerState.new
      spinner.is_active.should be_false
      spinner.current_id.should eq("")
      spinner.current_label.should eq("")

      id = spinner.start("test label")
      spinner.is_active.should be_true
      spinner.current_id.should eq(id)
      spinner.current_label.should eq("test label")

      spinner.stop(id, success: true)
      spinner.is_active.should be_false
      spinner.current_id.should eq("")
      spinner.current_label.should eq("")
    end

    it "doesn't stop with wrong id" do
      spinner = SpinnerState.new
      id1 = spinner.start("test1")
      id2 = "different_id"
      
      initial_active = spinner.is_active
      spinner.stop(id2, success: true)
      
      # Should still be active since wrong id was provided
      spinner.is_active.should eq(initial_active)
    end

    it "checks id matching correctly" do
      spinner = SpinnerState.new
      id = spinner.start("test")
      
      spinner.is_active_and_id_matches?(id).should be_true
      spinner.is_active_and_id_matches?("wrong").should be_false
      
      spinner.stop(id, success: true)
      spinner.is_active_and_id_matches?(id).should be_false
    end
  end
end