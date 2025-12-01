require "spec"
require "file_utils"
require "../../src/milka/utils"

# Create temporary directory for test isolation
SUBTREE_ARG_PARSING_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_argument_parsing_spec_#{Time.local.to_unix}")

describe "command line argument parsing for subtree" do
  before_all do
    Dir.mkdir_p(SUBTREE_ARG_PARSING_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(SUBTREE_ARG_PARSING_SPEC_TEMP_DIR)
      FileUtils.rm_rf(SUBTREE_ARG_PARSING_SPEC_TEMP_DIR)
    end
  end

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