require "./comment_info"

# Information about a single issue from a repository
class IssueInfo
  property number : Int32
  property title : String
  property body : String
  property state : String
  property created_at : String
  property updated_at : String
  property author : String
  property author_url : String
  property labels : Array(String)
  property html_url : String
  property comments : Array(CommentInfo)
  property context_url : String # Repository/tracker URL for JSON-LD

  def initialize(
    @number : Int32,
    @title : String,
    @body : String = "",
    @state : String = "open",
    @created_at : String = "",
    @updated_at : String = "",
    @author : String = "",
    @author_url : String = "",
    @labels : Array(String) = [] of String,
    @html_url : String = "",
    @comments : Array(CommentInfo) = [] of CommentInfo,
    @context_url : String = ""
  )
  end

  # Format issue as .org file content
  def to_org : String
    String.build do |str|
      str << "#+title: #{@title}\n"
      str << "#+id: #{@number}\n"
      str << "#+date: #{@created_at}\n"
      str << "#+state: #{@state}\n"
      str << "#+author: #{@author}\n"
      str << "#+url: #{@html_url}\n" unless @html_url.empty?
      str << "#+labels: #{@labels.join(", ")}\n" unless @labels.empty?
      str << "\n"
      str << @body
      str << "\n"

      # Add comments section if there are comments
      unless @comments.empty?
        str << "\n#+begin_comments\n"
        @comments.each do |comment|
          str << comment.to_org
        end
        str << "#+end_comments\n"
      end
    end
  end

  # Format issue as .md (Markdown) file content
  # Note: Title is only in YAML frontmatter, not duplicated as a heading
  def to_md : String
    String.build do |str|
      str << "---\n"
      str << "title: \"#{escape_yaml(@title)}\"\n"
      str << "id: #{@number}\n"
      str << "date: #{@created_at}\n"
      str << "state: #{@state}\n"
      str << "author: #{@author}\n"
      str << "url: #{@html_url}\n" unless @html_url.empty?
      str << "labels: [#{@labels.map { |l| "\"#{escape_yaml(l)}\"" }.join(", ")}]\n" unless @labels.empty?
      str << "---\n\n"
      str << @body
      str << "\n"

      # Add comments section if there are comments
      unless @comments.empty?
        str << "\n<begin-comments>\n"
        @comments.each do |comment|
          str << comment.to_md
        end
        str << "</begin-comments>\n"
      end
    end
  end

  # Format issue as JSON-LD (ForgeFed Ticket format)
  def to_json_ld : String
    String.build do |str|
      str << "{\n"
      str << "  \"@context\": [\n"
      str << "    \"https://www.w3.org/ns/activitystreams\",\n"
      str << "    \"https://forgefed.org/ns\"\n"
      str << "  ],\n"
      str << "  \"id\": \"#{escape_json(@html_url)}\",\n"
      str << "  \"type\": \"Ticket\",\n"
      str << "  \"context\": \"#{escape_json(@context_url)}\",\n" unless @context_url.empty?
      str << "  \"attributedTo\": \"#{escape_json(@author_url.empty? ? @author : @author_url)}\",\n"
      str << "  \"summary\": \"#{escape_json(@title)}\",\n"
      str << "  \"content\": \"#{escape_json(@body)}\",\n"
      str << "  \"mediaType\": \"text/markdown\",\n"
      str << "  \"published\": \"#{@created_at}\",\n"
      str << "  \"updated\": \"#{@updated_at}\",\n" unless @updated_at.empty?
      str << "  \"isResolved\": #{@state == "closed"},\n"

      # Add labels as tags
      unless @labels.empty?
        str << "  \"tag\": [\n"
        @labels.each_with_index do |label, idx|
          str << "    {\"type\": \"Label\", \"name\": \"#{escape_json(label)}\"}"
          str << "," if idx < @labels.size - 1
          str << "\n"
        end
        str << "  ],\n"
      end

      # Add comments as replies
      if @comments.empty?
        str << "  \"replies\": []\n"
      else
        str << "  \"replies\": [\n"
        @comments.each_with_index do |comment, idx|
          str << "    " << comment.to_json_ld.gsub("\n", "\n    ")
          str << "," if idx < @comments.size - 1
          str << "\n"
        end
        str << "  ]\n"
      end

      str << "}"
    end
  end

  private def escape_yaml(str : String) : String
    str.gsub("\"", "\\\"")
  end

  private def escape_json(str : String) : String
    str.gsub("\\", "\\\\")
       .gsub("\"", "\\\"")
       .gsub("\n", "\\n")
       .gsub("\r", "\\r")
       .gsub("\t", "\\t")
  end
end
