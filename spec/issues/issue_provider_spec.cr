require "spec"
require "../../src/milka/providers/issue_provider"

describe "IssueProvider" do
  describe ".parse_repo_url" do
    it "parses GitHub HTTPS URL" do
      result = IssueProvider.parse_repo_url("https://github.com/owner/repo")
      result.should eq({"owner", "repo"})
    end

    it "parses GitHub HTTPS URL with .git suffix" do
      result = IssueProvider.parse_repo_url("https://github.com/owner/repo.git")
      result.should eq({"owner", "repo"})
    end

    it "parses GitHub SSH URL" do
      result = IssueProvider.parse_repo_url("git@github.com:owner/repo.git")
      result.should eq({"owner", "repo"})
    end

    it "parses Codeberg HTTPS URL" do
      result = IssueProvider.parse_repo_url("https://codeberg.org/user/project")
      result.should eq({"user", "project"})
    end

    it "parses generic Gitea instance URL" do
      result = IssueProvider.parse_repo_url("https://gitea.example.com/org/project")
      result.should eq({"org", "project"})
    end

    it "returns nil for invalid URL" do
      result = IssueProvider.parse_repo_url("not-a-valid-url")
      result.should be_nil
    end
  end

  describe ".detect_provider_type" do
    it "detects GitHub" do
      IssueProvider.detect_provider_type("https://github.com/owner/repo").should eq("github")
    end

    it "detects Forgejo for Codeberg" do
      IssueProvider.detect_provider_type("https://codeberg.org/user/repo").should eq("forgejo")
    end

    it "detects Forgejo for gitea in URL" do
      IssueProvider.detect_provider_type("https://gitea.example.com/user/repo").should eq("forgejo")
    end

    it "defaults to forgejo for unknown hosts" do
      IssueProvider.detect_provider_type("https://git.example.com/user/repo").should eq("forgejo")
    end
  end

  describe ".extract_base_url" do
    it "extracts base URL from HTTPS" do
      IssueProvider.extract_base_url("https://github.com/owner/repo").should eq("https://github.com")
    end

    it "extracts base URL from HTTP" do
      IssueProvider.extract_base_url("http://gitea.local:3000/user/repo").should eq("http://gitea.local:3000")
    end

    it "extracts base URL from SSH" do
      IssueProvider.extract_base_url("git@github.com:owner/repo.git").should eq("https://github.com")
    end
  end
end
