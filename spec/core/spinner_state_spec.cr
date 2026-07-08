require "spec"
require "file_utils"
require "../../src/milka/git_operations"

# Create temporary directory for test isolation
SPINNER_STATE_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_spinner_state_spec_#{Time.local.to_unix}")

describe "SpinnerState" do
  before_all do
    Dir.mkdir_p(SPINNER_STATE_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(SPINNER_STATE_SPEC_TEMP_DIR)
      FileUtils.rm_rf(SPINNER_STATE_SPEC_TEMP_DIR)
    end
  end

  it "uses non-emoji status symbols" do
    SpinnerState::SUCCESS_SYMBOL.should eq("✓")
    SpinnerState::FAILURE_SYMBOL.should eq("✗")
  end

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
