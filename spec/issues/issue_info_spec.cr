require "spec"
require "../../src/milka/types/issue_info"

describe "IssueInfo" do
  describe "initialization" do
    it "creates an issue with all fields" do
      issue = IssueInfo.new(
        number: 42,
        title: "Test Issue",
        body: "This is the body",
        state: "open",
        created_at: "2024-01-15T10:00:00Z",
        updated_at: "2024-01-16T10:00:00Z",
        author: "testuser",
        labels: ["bug", "help wanted"],
        html_url: "https://github.com/owner/repo/issues/42"
      )

      issue.number.should eq(42)
      issue.title.should eq("Test Issue")
      issue.body.should eq("This is the body")
      issue.state.should eq("open")
      issue.created_at.should eq("2024-01-15T10:00:00Z")
      issue.updated_at.should eq("2024-01-16T10:00:00Z")
      issue.author.should eq("testuser")
      issue.labels.should eq(["bug", "help wanted"])
      issue.html_url.should eq("https://github.com/owner/repo/issues/42")
    end

    it "creates an issue with minimal fields" do
      issue = IssueInfo.new(number: 1, title: "Minimal Issue")

      issue.number.should eq(1)
      issue.title.should eq("Minimal Issue")
      issue.body.should eq("")
      issue.state.should eq("open")
      issue.labels.should be_empty
    end
  end

  describe "#to_org" do
    it "formats issue as org file" do
      issue = IssueInfo.new(
        number: 42,
        title: "Test Issue",
        body: "Issue body content",
        state: "open",
        created_at: "2024-01-15T10:00:00Z",
        author: "testuser",
        labels: ["bug"],
        html_url: "https://github.com/owner/repo/issues/42"
      )

      org = issue.to_org

      org.should contain("#+title: Test Issue")
      org.should contain("#+id: 42")
      org.should contain("#+date: 2024-01-15T10:00:00Z")
      org.should contain("#+state: open")
      org.should contain("#+author: testuser")
      org.should contain("#+url: https://github.com/owner/repo/issues/42")
      org.should contain("#+labels: bug")
      org.should contain("Issue body content")
    end

    it "omits url and labels if empty" do
      issue = IssueInfo.new(
        number: 1,
        title: "Simple Issue",
        body: "Body",
        state: "closed"
      )

      org = issue.to_org

      org.should contain("#+title: Simple Issue")
      org.should_not contain("#+url:")
      org.should_not contain("#+labels:")
    end
  end

  describe "#to_md" do
    it "formats issue as markdown file with YAML frontmatter" do
      issue = IssueInfo.new(
        number: 42,
        title: "Test Issue",
        body: "Issue body content",
        state: "open",
        created_at: "2024-01-15T10:00:00Z",
        author: "testuser",
        labels: ["bug", "feature"],
        html_url: "https://github.com/owner/repo/issues/42"
      )

      md = issue.to_md

      md.should contain("---")
      md.should contain("title: \"Test Issue\"")
      md.should contain("id: 42")
      md.should contain("date: 2024-01-15T10:00:00Z")
      md.should contain("state: open")
      md.should contain("author: testuser")
      md.should contain("url: https://github.com/owner/repo/issues/42")
      md.should contain("labels: [\"bug\", \"feature\"]")
      md.should contain("# Test Issue")
      md.should contain("Issue body content")
    end

    it "escapes quotes in title for YAML" do
      issue = IssueInfo.new(
        number: 1,
        title: "Issue with \"quotes\" in title",
        body: "Body"
      )

      md = issue.to_md

      md.should contain("title: \"Issue with \\\"quotes\\\" in title\"")
    end
  end
end
