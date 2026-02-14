require "spec"
require "../../src/milka/types/issue_info"
require "../../src/milka/types/comment_info"

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
      issue.comments.should be_empty
    end

    it "creates an issue with comments" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "Test comment",
        author: "commenter"
      )
      issue = IssueInfo.new(
        number: 42,
        title: "Issue with comments",
        body: "Body",
        comments: [comment]
      )

      issue.comments.size.should eq(1)
      issue.comments[0].body.should eq("Test comment")
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

    it "includes comments section when comments exist" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "This is a comment",
        author: "commenter",
        author_url: "https://github.com/commenter"
      )
      issue = IssueInfo.new(
        number: 1,
        title: "Issue with comments",
        body: "Body",
        comments: [comment]
      )

      org = issue.to_org

      org.should contain("#+begin_comments")
      org.should contain("#+end_comments")
      org.should contain(":author: [[https://github.com/commenter][commenter]]")
      org.should contain(":id: 123")
      org.should contain("This is a comment")
    end

    it "omits comments section when no comments" do
      issue = IssueInfo.new(
        number: 1,
        title: "No comments",
        body: "Body"
      )

      org = issue.to_org

      org.should_not contain("#+begin_comments")
      org.should_not contain("#+end_comments")
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
      md.should contain("Issue body content")
    end

    it "does not duplicate title as heading" do
      issue = IssueInfo.new(
        number: 42,
        title: "Test Issue",
        body: "Issue body content"
      )

      md = issue.to_md

      # Title should be in frontmatter
      md.should contain("title: \"Test Issue\"")
      # But NOT as a markdown heading
      md.should_not contain("# Test Issue")
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

    it "includes comments section when comments exist" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "This is a comment",
        author: "commenter",
        author_url: "https://github.com/commenter"
      )
      issue = IssueInfo.new(
        number: 1,
        title: "Issue with comments",
        body: "Body",
        comments: [comment]
      )

      md = issue.to_md

      md.should contain("<begin-comments>")
      md.should contain("</begin-comments>")
      md.should contain("<comments-comment")
      md.should contain("author=\"https://github.com/commenter\"")
      md.should contain("id=\"123\"")
      md.should contain("This is a comment")
    end
  end

  describe "#to_json_ld" do
    it "formats issue as JSON-LD with ForgeFed Ticket type" do
      issue = IssueInfo.new(
        number: 42,
        title: "Test Issue",
        body: "Issue body content",
        state: "open",
        created_at: "2024-01-15T10:00:00Z",
        updated_at: "2024-01-16T10:00:00Z",
        author: "testuser",
        author_url: "https://github.com/testuser",
        labels: ["bug"],
        html_url: "https://github.com/owner/repo/issues/42",
        context_url: "https://github.com/owner/repo"
      )

      json = issue.to_json_ld

      json.should contain("\"@context\":")
      json.should contain("https://www.w3.org/ns/activitystreams")
      json.should contain("https://forgefed.org/ns")
      json.should contain("\"type\": \"Ticket\"")
      json.should contain("\"summary\": \"Test Issue\"")
      json.should contain("\"content\": \"Issue body content\"")
      json.should contain("\"mediaType\": \"text/markdown\"")
      json.should contain("\"published\": \"2024-01-15T10:00:00Z\"")
      json.should contain("\"isResolved\": false")
      json.should contain("\"attributedTo\": \"https://github.com/testuser\"")
    end

    it "sets isResolved to true for closed issues" do
      issue = IssueInfo.new(
        number: 1,
        title: "Closed Issue",
        body: "Body",
        state: "closed"
      )

      json = issue.to_json_ld

      json.should contain("\"isResolved\": true")
    end

    it "includes labels as tags" do
      issue = IssueInfo.new(
        number: 1,
        title: "Tagged Issue",
        body: "Body",
        labels: ["bug", "enhancement"]
      )

      json = issue.to_json_ld

      json.should contain("\"tag\":")
      json.should contain("\"type\": \"Label\"")
      json.should contain("\"name\": \"bug\"")
      json.should contain("\"name\": \"enhancement\"")
    end

    it "includes comments as replies" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "Comment text",
        author: "commenter",
        created_at: "2024-01-15T11:00:00Z"
      )
      issue = IssueInfo.new(
        number: 1,
        title: "Issue with comments",
        body: "Body",
        comments: [comment]
      )

      json = issue.to_json_ld

      json.should contain("\"replies\":")
      json.should contain("\"type\": \"Note\"")
      json.should contain("\"content\": \"Comment text\"")
    end

    it "escapes special characters in JSON" do
      issue = IssueInfo.new(
        number: 1,
        title: "Issue with \"quotes\" and\nnewlines",
        body: "Body with\ttabs"
      )

      json = issue.to_json_ld

      json.should contain("\\\"quotes\\\"")
      json.should contain("\\n")
      json.should contain("\\t")
    end
  end
end
