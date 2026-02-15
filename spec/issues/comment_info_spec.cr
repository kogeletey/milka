require "spec"
require "../../src/milka/types/comment_info"

describe "CommentInfo" do
  describe "initialization" do
    it "creates a comment with all fields" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "This is a comment",
        author: "testuser",
        author_url: "https://github.com/testuser",
        created_at: "2024-01-15T10:00:00Z",
        updated_at: "2024-01-16T10:00:00Z",
        html_url: "https://github.com/owner/repo/issues/42#issuecomment-123"
      )

      comment.id.should eq(123_i64)
      comment.body.should eq("This is a comment")
      comment.author.should eq("testuser")
      comment.author_url.should eq("https://github.com/testuser")
      comment.created_at.should eq("2024-01-15T10:00:00Z")
      comment.updated_at.should eq("2024-01-16T10:00:00Z")
      comment.html_url.should eq("https://github.com/owner/repo/issues/42#issuecomment-123")
    end

    it "creates a comment with minimal fields" do
      comment = CommentInfo.new(id: 1_i64)

      comment.id.should eq(1_i64)
      comment.body.should eq("")
      comment.author.should eq("")
      comment.author_url.should eq("")
    end
  end

  describe "#to_org" do
    it "formats comment with author URL as org-mode link" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "Comment content",
        author: "testuser",
        author_url: "https://github.com/testuser"
      )

      org = comment.to_org

      org.should contain(":PROPERTIES:")
      org.should contain(":author: [[https://github.com/testuser][testuser]]")
      org.should contain(":id: 123")
      org.should contain(":END:")
      org.should contain("Comment content")
    end

    it "formats comment with plain author when no URL" do
      comment = CommentInfo.new(
        id: 456_i64,
        body: "Comment body",
        author: "plain_user"
      )

      org = comment.to_org

      org.should contain(":author: plain_user")
      org.should_not contain("[[")
    end
  end

  describe "#to_md" do
    it "formats comment as HTML element with author URL" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "Comment content",
        author: "testuser",
        author_url: "https://github.com/testuser"
      )

      md = comment.to_md

      md.should contain("<comments-comment")
      md.should contain("author=\"https://github.com/testuser\"")
      md.should contain("id=\"123\"")
      md.should contain("Comment content")
      md.should contain("</comments-comment>")
    end

    it "uses author name when no URL available" do
      comment = CommentInfo.new(
        id: 456_i64,
        body: "Body",
        author: "plain_user"
      )

      md = comment.to_md

      md.should contain("author=\"plain_user\"")
    end
  end

  describe "#to_json_ld" do
    it "formats comment as ForgeFed Note" do
      comment = CommentInfo.new(
        id: 123_i64,
        body: "Comment text",
        author: "testuser",
        author_url: "https://github.com/testuser",
        created_at: "2024-01-15T10:00:00Z",
        html_url: "https://github.com/owner/repo/issues/42#issuecomment-123"
      )

      json = comment.to_json_ld

      json.should contain("\"type\": \"Note\"")
      json.should contain("\"id\": 123")
      json.should contain("\"attributedTo\": \"https://github.com/testuser\"")
      json.should contain("\"content\": \"Comment text\"")
      json.should contain("\"mediaType\": \"text/markdown\"")
      json.should contain("\"published\": \"2024-01-15T10:00:00Z\"")
      json.should contain("\"url\": \"https://github.com/owner/repo/issues/42#issuecomment-123\"")
    end

    it "uses author name when no URL available" do
      comment = CommentInfo.new(
        id: 456_i64,
        body: "Body",
        author: "plain_user"
      )

      json = comment.to_json_ld

      json.should contain("\"attributedTo\": \"plain_user\"")
    end

    it "escapes special characters in JSON" do
      comment = CommentInfo.new(
        id: 1_i64,
        body: "Comment with \"quotes\" and\nnewlines"
      )

      json = comment.to_json_ld

      json.should contain("\\\"quotes\\\"")
      json.should contain("\\n")
    end
  end
end
