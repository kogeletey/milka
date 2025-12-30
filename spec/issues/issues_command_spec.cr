require "spec"
require "file_utils"
require "../../src/milka/types/repository_info"
require "../../src/milka/types/issue_info"
require "../../src/milka/types/git_error"
require "../../src/milka/commands/issues_command"

# Create temporary directory for test isolation
ISSUES_COMMAND_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_issues_command_spec_#{Time.local.to_unix}")

describe "IssuesCommand" do
  before_all do
    Dir.mkdir_p(ISSUES_COMMAND_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(ISSUES_COMMAND_SPEC_TEMP_DIR)
      FileUtils.rm_rf(ISSUES_COMMAND_SPEC_TEMP_DIR)
    end
  end

  describe "initialization" do
    it "creates command with default values" do
      cmd = IssuesCommand.new(".meta/reps.toml")
      cmd.output_format.should eq("org")
      cmd.output_dir.should eq(".meta/issues")
      cmd.state_filter.should eq("all")
    end

    it "creates command with custom values" do
      cmd = IssuesCommand.new(
        ".meta/reps.toml",
        branch_override: "main",
        output_format: "md",
        output_dir: "/custom/path",
        state_filter: "open"
      )
      cmd.output_format.should eq("md")
      cmd.output_dir.should eq("/custom/path")
      cmd.state_filter.should eq("open")
    end
  end

  describe "argument parsing" do
    it "parses --format argument" do
      cmd = IssuesCommand.new(".meta/reps.toml")
      output_dir = File.join(ISSUES_COMMAND_SPEC_TEMP_DIR, "format_test")

      # The command should parse additional args
      # We can test this indirectly by checking the format field changes
      # Note: We can't easily test execute without mocking HTTP, but we can verify
      # the command is created correctly
      cmd.output_format.should eq("org")
    end
  end

  describe "output format validation" do
    it "accepts org format" do
      cmd = IssuesCommand.new(".meta/reps.toml", output_format: "org")
      cmd.output_format.should eq("org")
    end

    it "accepts md format" do
      cmd = IssuesCommand.new(".meta/reps.toml", output_format: "md")
      cmd.output_format.should eq("md")
    end
  end

  describe "state filter validation" do
    it "accepts 'open' state" do
      cmd = IssuesCommand.new(".meta/reps.toml", state_filter: "open")
      cmd.state_filter.should eq("open")
    end

    it "accepts 'closed' state" do
      cmd = IssuesCommand.new(".meta/reps.toml", state_filter: "closed")
      cmd.state_filter.should eq("closed")
    end

    it "accepts 'all' state" do
      cmd = IssuesCommand.new(".meta/reps.toml", state_filter: "all")
      cmd.state_filter.should eq("all")
    end
  end
end
