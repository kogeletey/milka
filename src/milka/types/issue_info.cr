# Information about a single issue from a repository
class IssueInfo
  property number : Int32
  property title : String
  property body : String
  property state : String
  property created_at : String
  property updated_at : String
  property author : String
  property labels : Array(String)
  property html_url : String

  def initialize(
    @number : Int32,
    @title : String,
    @body : String = "",
    @state : String = "open",
    @created_at : String = "",
    @updated_at : String = "",
    @author : String = "",
    @labels : Array(String) = [] of String,
    @html_url : String = ""
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
    end
  end

  # Format issue as .md (Markdown) file content
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
      str << "# #{@title}\n\n"
      str << @body
      str << "\n"
    end
  end

  private def escape_yaml(str : String) : String
    str.gsub("\"", "\\\"")
  end
end
