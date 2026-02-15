# Information about a single comment on an issue
class CommentInfo
  property id : Int64
  property body : String
  property author : String
  property author_url : String
  property created_at : String
  property updated_at : String
  property html_url : String

  def initialize(
    @id : Int64,
    @body : String = "",
    @author : String = "",
    @author_url : String = "",
    @created_at : String = "",
    @updated_at : String = "",
    @html_url : String = ""
  )
  end

  # Format comment as org-mode format
  # Using the requested format:
  # #+begin_comments
  # :PROPERTIES:
  # :author: author link in org format
  # :id: comment_id
  # :END:
  # {{ comment content }}
  # #+end_comments
  def to_org : String
    String.build do |str|
      str << ":PROPERTIES:\n"
      if @author_url.empty?
        str << ":author: #{@author}\n"
      else
        str << ":author: [[#{@author_url}][#{@author}]]\n"
      end
      str << ":id: #{@id}\n"
      str << ":END:\n"
      str << @body
      str << "\n"
    end
  end

  # Format comment as markdown/HTML format
  # Using the requested format:
  # <comments-comment
  # author="author_link"
  # id="id"
  # >
  # {{ comment content }}
  # </comments-comment>
  def to_md : String
    author_attr = @author_url.empty? ? @author : @author_url
    String.build do |str|
      str << "<comments-comment\n"
      str << "author=\"#{author_attr}\"\n"
      str << "id=\"#{@id}\"\n"
      str << ">\n"
      str << @body
      str << "\n</comments-comment>\n"
    end
  end

  # Format comment as JSON-LD (ForgeFed Note format)
  def to_json_ld : String
    String.build do |str|
      str << "{\n"
      str << "  \"type\": \"Note\",\n"
      str << "  \"id\": #{@id},\n"
      str << "  \"attributedTo\": \"#{escape_json(@author_url.empty? ? @author : @author_url)}\",\n"
      str << "  \"content\": \"#{escape_json(@body)}\",\n"
      str << "  \"mediaType\": \"text/markdown\",\n"
      str << "  \"published\": \"#{@created_at}\""
      unless @html_url.empty?
        str << ",\n  \"url\": \"#{escape_json(@html_url)}\""
      end
      str << "\n}"
    end
  end

  private def escape_json(str : String) : String
    str.gsub("\\", "\\\\")
       .gsub("\"", "\\\"")
       .gsub("\n", "\\n")
       .gsub("\r", "\\r")
       .gsub("\t", "\\t")
  end
end
