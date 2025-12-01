require "spec"
require "file_utils"
require "../../src/milka/utils"
require "../../src/milka/types/repository_info"

# Create temporary directory for test isolation
UTILS_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_utils_spec_#{Time.local.to_unix}")

describe "Utility functions" do
  before_all do
    Dir.mkdir_p(UTILS_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(UTILS_SPEC_TEMP_DIR)
      FileUtils.rm_rf(UTILS_SPEC_TEMP_DIR)
    end
  end

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

  it "recognizes create command" do
    get_command_from_string("create").should eq(:create)
    get_command_from_string("clone").should eq(:clone)
    get_command_from_string("invalid").should be_nil
  end

  describe "URL detection for clone command" do
    it "should detect HTTP URLs" do
      url = "http://github.com/user/repo.git"
      (url.starts_with?("http://") || url.starts_with?("https://") || url.starts_with?("git@")).should be_true
    end

    it "should detect HTTPS URLs" do
      url = "https://github.com/user/repo.git"
      (url.starts_with?("http://") || url.starts_with?("https://") || url.starts_with?("git@")).should be_true
    end

    it "should detect SSH URLs" do
      url = "git@github.com:user/repo.git"
      (url.starts_with?("http://") || url.starts_with?("https://") || url.starts_with?("git@")).should be_true
    end

    it "should not detect regular repo names as URLs" do
      repo_name = "my-repo"
      (repo_name.starts_with?("http://") || repo_name.starts_with?("https://") || repo_name.starts_with?("git@")).should be_false
    end

    it "should handle URL detection in argument processing logic" do
      # Test the logic that determines if a repo_name parameter is a URL or a repository name from config
      repo_name = "git@github.com:user/repo.git"
      additional_args = [] of String

      is_url = repo_name.starts_with?("http://") || repo_name.starts_with?("https://") || repo_name.starts_with?("git@")

      is_url.should be_true
    end

    it "should handle URL with custom directory name" do
      # Test the logic for handling: milka clone <custom_dir_name> <URL>
      repo_name = "custom_dir"
      additional_args = ["git@github.com:user/repo.git"]

      has_url_in_additional_args = additional_args.size == 1 &&
        (additional_args[0].starts_with?("http://") || additional_args[0].starts_with?("https://") || additional_args[0].starts_with?("git@"))

      has_url_in_additional_args.should be_true
    end
  end

  describe "Repository name extraction from URLs" do
    it "should extract repository name from SSH URL with .git extension" do
      clean_url = "git@github.com:user/repo-name.git".gsub(/\/$/, "")
      name = if clean_url.starts_with?("git@")
        path_part = clean_url.split(":")[1]?
        if path_part
          File.basename(path_part, ".git").split(/[?#]/)[0]
        else
          File.basename(clean_url, ".git").split(/[?#]/)[0]
        end
      else
        File.basename(clean_url, ".git").split(/[?#]/)[0]
      end

      name.should eq("repo-name")
    end

    it "should extract repository name from SSH URL without .git extension" do
      clean_url_no_git = "git@github.com:user/repo-name".gsub(/\/$/, "")
      name_no_git = if clean_url_no_git.starts_with?("git@")
        path_part = clean_url_no_git.split(":")[1]?
        if path_part
          File.basename(path_part, ".git").split(/[?#]/)[0]
        else
          File.basename(clean_url_no_git, ".git").split(/[?#]/)[0]
        end
      else
        File.basename(clean_url_no_git, ".git").split(/[?#]/)[0]
      end

      name_no_git.should eq("repo-name")
    end

    it "should extract repository name from complex SSH URL" do
      clean_complex_url = "git@github.com:org/subgroup/repo.git".gsub(/\/$/, "")
      name_complex = if clean_complex_url.starts_with?("git@")
        path_part = clean_complex_url.split(":")[1]?
        if path_part
          File.basename(path_part, ".git").split(/[?#]/)[0]
        else
          File.basename(clean_complex_url, ".git").split(/[?#]/)[0]
        end
      else
        File.basename(clean_complex_url, ".git").split(/[?#]/)[0]
      end

      name_complex.should eq("repo")
    end

    it "should extract repository name from HTTPS URL with .git extension" do
      clean_url = "https://github.com/user/repo-name.git".gsub(/\/$/, "")
      name = File.basename(clean_url, ".git").split(/[?#]/)[0]
      name.should eq("repo-name")
    end

    it "should extract repository name from HTTPS URL without .git extension" do
      clean_https_no_git = "https://github.com/user/repo-name".gsub(/\/$/, "")
      name_https_no_git = File.basename(clean_https_no_git, ".git").split(/[?#]/)[0]
      name_https_no_git.should eq("repo-name")
    end
  end
end