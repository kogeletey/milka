require "spec"
require "file_utils"
require "../../src/milka/utils"

# Create temporary directory for test isolation
ARG_PARSING_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_argument_parsing_spec_#{Time.local.to_unix}")

describe "Argument parsing" do
  before_all do
    Dir.mkdir_p(ARG_PARSING_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(ARG_PARSING_SPEC_TEMP_DIR)
      FileUtils.rm_rf(ARG_PARSING_SPEC_TEMP_DIR)
    end
  end

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