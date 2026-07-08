require "spec"
require "file_utils"
require "../../src/milka/git_operations"

GIT_MANAGER_CLONE_SPEC_TEMP_DIR = File.join(Dir.tempdir, "milka_git_manager_clone_spec_#{Time.local.to_unix}")

def run_git!(args : Array(String), chdir : String)
  result = Process.run("git", args, chdir: chdir)
  result.success?.should be_true
end

def create_source_repo(root_path : String, name : String) : String
  source_path = File.join(root_path, "#{name}_source")
  Dir.mkdir_p(source_path)

  run_git!(["init"], chdir: source_path)
  run_git!(["checkout", "-B", "main"], chdir: source_path)
  File.write(File.join(source_path, "README.md"), "# #{name}\n")
  run_git!(["add", "README.md"], chdir: source_path)
  run_git!(["-c", "user.email=milka@example.test", "-c", "user.name=Milka Test", "commit", "-m", "Initial commit"], chdir: source_path)

  source_path
end

def clone_with_gitignore(initial_gitignore : String?, repo_name : String) : String
  test_path = File.join(GIT_MANAGER_CLONE_SPEC_TEMP_DIR, repo_name)
  FileUtils.rm_rf(test_path) if Dir.exists?(test_path)
  Dir.mkdir_p(test_path)

  source_path = create_source_repo(test_path, repo_name)
  workspace_path = File.join(test_path, "workspace")
  Dir.mkdir_p(workspace_path)

  if initial_gitignore
    File.write(File.join(workspace_path, ".gitignore"), initial_gitignore)
  end

  Dir.cd(workspace_path) do
    GitManager.new.clone_repository(RepositoryInfo.new(repo_name, source_path, "main", "", "git"))
  end

  File.read(File.join(workspace_path, ".gitignore"))
end

describe "GitManager clone .gitignore updates" do
  before_all do
    Dir.mkdir_p(GIT_MANAGER_CLONE_SPEC_TEMP_DIR)
  end

  after_all do
    if Dir.exists?(GIT_MANAGER_CLONE_SPEC_TEMP_DIR)
      FileUtils.rm_rf(GIT_MANAGER_CLONE_SPEC_TEMP_DIR)
    end
  end

  it "creates .gitignore with a trailing newline when missing" do
    clone_with_gitignore(nil, "missing_gitignore").should eq("missing_gitignore/\n")
  end

  it "appends after existing content without a trailing newline" do
    clone_with_gitignore("build", "no_trailing_newline").should eq("build\nno_trailing_newline/\n")
  end

  it "appends after existing content with a trailing newline" do
    clone_with_gitignore("build\n", "with_trailing_newline").should eq("build\nwith_trailing_newline/\n")
  end

  it "does not duplicate an existing exact entry" do
    clone_with_gitignore("duplicate_entry/\nother/\n", "duplicate_entry").should eq("duplicate_entry/\nother/\n")
  end
end
