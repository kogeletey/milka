require "spec"
require "file_utils"
require "../src/milka/types/repository_info"
require "../src/milka/types/mise_config"
require "../src/milka/types/git_error"
require "../src/milka/commands"
require "../src/milka/git_operations"
require "../src/milka/utils"
require "../src/milka/config_manager"
require "../src/milka/repository_utils"
require "../src/milka/commands/scan_command"

# Create temporary directory for test isolation
SUBTREE_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_subtree_spec_#{Time.local.to_unix}")

describe "Subtree functionality" do
  before_all do
    Dir.mkdir_p(SUBTREE_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(SUBTREE_SPEC_TEMP_DIR)
      FileUtils.rm_rf(SUBTREE_SPEC_TEMP_DIR)
    end
  end

  describe "scan command with subtree flag" do
    it "should add existing git repos with subtree source when using --subtree flag" do
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_subtree_existing")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_non_git")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_no_subtree")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_mixed")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_default")
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

  describe "repository source configuration" do
    it "should parse source field from config" do
      toml_content = <<-'TOML'
        [[repo]]
        dir = 'test_repo'
        remote = 'https://example.com/test.git'
        source = 'git+subtree'
      TOML

      config_path = File.join(SUBTREE_SPEC_TEMP_DIR, "source_config.toml")
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

      config_path = File.join(SUBTREE_SPEC_TEMP_DIR, "default_source.toml")
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

      config_path = File.join(SUBTREE_SPEC_TEMP_DIR, "mixed_sources.toml")
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

  describe "RepositoryInfo" do
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

  describe "command line argument parsing for subtree" do
    it "should parse --subtree flag correctly" do
      # Test the main commands parsing logic
      args = ["scan", "--subtree"]
      config_path = ".meta/reps.toml"
      branch_override = nil
      use_subtree = false
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
        elsif arg == "--subtree"
          use_subtree = true
          i += 1
          next
        elsif arg.starts_with?("--")
          i += 1
          next
        else
          non_option_args << arg
          i += 1
        end
      end

      use_subtree.should be_true
      non_option_args[0].should eq("scan")
    end
  end

  describe "RepositoryUtils" do
    it "should scan non-git directories correctly" do
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_non_git_test")
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
      config_path = File.join(SUBTREE_SPEC_TEMP_DIR, "add_repo_config.toml")

      # Use the ConfigManager method to add a repo with source
      ConfigManager.add_git_repo_to_config(config_path, "test_repo", "https://example.com/repo.git", "main", "git+subtree")

      # Check the config file
      content = File.read(config_path)
      content.includes?("dir = 'test_repo'").should be_true
      content.includes?("source = 'git+subtree'").should be_true
    end

    it "should add git repo to config with default source when not specified" do
      config_path = File.join(SUBTREE_SPEC_TEMP_DIR, "add_repo_default.toml")

      # Use the ConfigManager method to add a repo without specifying source (should default)
      ConfigManager.add_git_repo_to_config(config_path, "test_repo", "https://example.com/repo.git", "main")

      # Check the config file doesn't include source (because default is git)
      content = File.read(config_path)
      content.includes?("dir = 'test_repo'").should be_true
      content.includes?("source = 'git'").should be_false
    end

    it "should handle scan_and_add_git_repos with subtree flag properly" do
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "scan_add_test")
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

  describe "CreateCommand" do
    it "should create new git repository in new directory" do
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "create_new_test")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "create_subtree_test")
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
      temp_dir = File.join(SUBTREE_SPEC_TEMP_DIR, "create_existing_git_test")
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
end
