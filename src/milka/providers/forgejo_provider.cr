require "http/client"
require "json"
require "./issue_provider"
require "../types/issue_info"
require "../types/comment_info"
require "../types/git_error"

# Forgejo/Gitea issue provider - fetches issues from Forgejo/Gitea API
# Also works with Codeberg and other Forgejo/Gitea-based instances
class ForgejoIssueProvider < IssueProvider
  USER_AGENT = "milka-cli"

  property base_url : String
  property fetch_comments : Bool

  def initialize(@base_url : String = "https://codeberg.org", @fetch_comments : Bool = true)
    # Ensure no trailing slash
    @base_url = @base_url.rstrip('/')
  end

  def name : String
    "Forgejo"
  end

  def fetch_issues(owner : String, repo : String, state : String = "all") : Array(IssueInfo)
    issues = [] of IssueInfo
    page = 1
    limit = 50

    loop do
      url = "#{@base_url}/api/v1/repos/#{owner}/#{repo}/issues?state=#{state}&page=#{page}&limit=#{limit}"

      response = make_request(url)

      case response.status_code
      when 200
        parsed_issues = parse_issues_response(response.body, owner, repo)
        break if parsed_issues.empty?

        issues.concat(parsed_issues)
        page += 1

        # If we got less than limit results, we've reached the end
        break if parsed_issues.size < limit
      when 401
        raise GitError.new("Forgejo API: Authentication required. Set FORGEJO_TOKEN environment variable for private repositories.")
      when 403
        raise GitError.new("Forgejo API: Access forbidden. Repository may be private - set FORGEJO_TOKEN environment variable.")
      when 404
        raise GitError.new("Forgejo API: Repository '#{owner}/#{repo}' not found at #{@base_url}.")
      else
        raise GitError.new("Forgejo API error: HTTP #{response.status_code} - #{response.body}")
      end
    end

    # Fetch comments for each issue if enabled
    if @fetch_comments
      issues.each do |issue|
        fetch_comments_for_issue(owner, repo, issue)
      end
    end

    issues
  end

  private def fetch_comments_for_issue(owner : String, repo : String, issue : IssueInfo)
    url = "#{@base_url}/api/v1/repos/#{owner}/#{repo}/issues/#{issue.number}/comments"

    begin
      response = make_request(url)

      if response.status_code == 200
        comments = parse_comments_response(response.body)
        issue.comments = comments
      end
    rescue
      # Silently ignore comment fetch errors - issue data is still valuable
    end
  end

  private def parse_comments_response(body : String) : Array(CommentInfo)
    comments = [] of CommentInfo

    begin
      json = JSON.parse(body)

      json.as_a.each do |item|
        id = item["id"].as_i64
        body_text = item["body"]?.try(&.as_s?) || ""
        author = item["user"]?.try(&.["login"]?.try(&.as_s)) || "unknown"
        author_url = item["user"]?.try(&.["html_url"]?.try(&.as_s)) || ""
        created_at = item["created_at"]?.try(&.as_s) || ""
        updated_at = item["updated_at"]?.try(&.as_s) || ""
        html_url = item["html_url"]?.try(&.as_s) || ""

        comments << CommentInfo.new(
          id: id,
          body: body_text,
          author: author,
          author_url: author_url,
          created_at: created_at,
          updated_at: updated_at,
          html_url: html_url
        )
      end
    rescue e : JSON::ParseException
      # Return empty array on parse error
    end

    comments
  end

  private def make_request(url : String) : HTTP::Client::Response
    uri = URI.parse(url)

    HTTP::Client.new(uri) do |client|
      client.connect_timeout = 30.seconds
      client.read_timeout = 30.seconds

      headers = HTTP::Headers{
        "User-Agent" => USER_AGENT,
        "Accept"     => "application/json",
      }

      # Use FORGEJO_TOKEN if available for authentication
      if token = ENV["FORGEJO_TOKEN"]?
        headers["Authorization"] = "token #{token}"
      end

      query_string = uri.query ? "?#{uri.query}" : ""
      return client.get(uri.path.not_nil! + query_string, headers: headers)
    end
  end

  private def parse_issues_response(body : String, owner : String, repo : String) : Array(IssueInfo)
    issues = [] of IssueInfo
    context_url = "#{@base_url}/#{owner}/#{repo}"

    begin
      json = JSON.parse(body)

      json.as_a.each do |item|
        # Forgejo API includes pull_requests in separate endpoint, but check anyway
        next if item["pull_request"]?

        number = item["number"].as_i
        title = item["title"].as_s
        body_text = item["body"]?.try(&.as_s?) || ""
        state = item["state"].as_s
        created_at = item["created_at"].as_s
        updated_at = item["updated_at"].as_s
        author = item["user"]?.try(&.["login"]?.try(&.as_s)) || "unknown"
        author_url = item["user"]?.try(&.["html_url"]?.try(&.as_s)) || ""
        html_url = item["html_url"]?.try(&.as_s) || ""

        labels = [] of String
        if label_arr = item["labels"]?.try(&.as_a?)
          labels = label_arr.compact_map { |l| l["name"]?.try(&.as_s) }
        end

        issues << IssueInfo.new(
          number: number,
          title: title,
          body: body_text,
          state: state,
          created_at: created_at,
          updated_at: updated_at,
          author: author,
          author_url: author_url,
          labels: labels,
          html_url: html_url,
          context_url: context_url
        )
      end
    rescue e : JSON::ParseException
      raise GitError.new("Failed to parse Forgejo API response: #{e.message}")
    end

    issues
  end
end
