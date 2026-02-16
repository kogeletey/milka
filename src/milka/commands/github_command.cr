require "../../milka/types/repository_info"
require "../../milka/types/git_error"
require "../utils"
require "../config_manager"
require "http/client"
require "json"

class GithubCommand
  def initialize(@config_path : String, @branch_override : String? = nil, @use_subtree : Bool = false)
  end

  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil, additional_args : Array(String) = [] of String)
    # repo_name is the organization or user name
    org_name = repo_name

    if org_name.nil? || org_name.empty?
      Utils.print_error("Error: Organization or username is required")
      Utils.print_info("Usage: milka github <org-name> [--clone]")
      Utils.print_info("       milka github <org-name> --clone   # Also clone the repositories")
      return
    end

    # Check if we should also clone the repos
    should_clone = additional_args.includes?("--clone")

    Utils.print_info("Fetching repositories for organization/user: #{org_name}")

    begin
      repos = fetch_github_repos(org_name)

      if repos.empty?
        Utils.print_warning("No repositories found for: #{org_name}")
        return
      end

      Utils.print_success("Found #{repos.size} repositories")

      added_count = 0
      cloned_count = 0

      repos.each do |repo|
        repo_info = parse_repo_info(repo)
        next if repo_info.nil?

        # Add to config
        source = @use_subtree ? "git+subtree" : "git"
        if ConfigManager.repo_exists_in_config(@config_path, repo_info[:name])
          Utils.print_info("  #{repo_info[:name]} already in config, skipping...")
        else
          ConfigManager.add_git_repo_to_config(@config_path, repo_info[:name], repo_info[:url], repo_info[:branch], source)
          Utils.print_success("  Added #{repo_info[:name]} to config")
          added_count += 1
        end

        # Clone if requested
        if should_clone && !Dir.exists?(repo_info[:name])
          Utils.print_info("  Cloning #{repo_info[:name]}...")
          if clone_repository(repo_info[:url], repo_info[:name], repo_info[:branch])
            Utils.print_success("  Cloned #{repo_info[:name]}")
            cloned_count += 1
          else
            Utils.print_error("  Failed to clone #{repo_info[:name]}")
          end
        elsif should_clone && Dir.exists?(repo_info[:name])
          Utils.print_info("  #{repo_info[:name]} already exists locally, skipping clone...")
        end
      end

      Utils.print_success("GitHub scan completed!")
      Utils.print_info("  Added #{added_count} repositories to #{@config_path}")
      if should_clone
        Utils.print_info("  Cloned #{cloned_count} repositories")
      end
    rescue e : Exception
      Utils.print_error("Error fetching repositories: #{e.message}")
    end
  end

  private def fetch_github_repos(org_name : String) : Array(JSON::Any)
    all_repos = [] of JSON::Any
    page = 1
    per_page = 100

    # First try as organization
    loop do
      url = "https://api.github.com/orgs/#{org_name}/repos?page=#{page}&per_page=#{per_page}"
      response = make_github_request(url)

      if response.nil?
        # Try as user instead
        Utils.print_info("Not found as organization, trying as user...")
        return fetch_user_repos(org_name)
      end

      repos = JSON.parse(response)
      break if !repos.as_a? || repos.as_a.empty?

      all_repos.concat(repos.as_a)

      # If we got fewer than per_page, we've reached the end
      break if repos.as_a.size < per_page

      page += 1
    end

    all_repos
  end

  private def fetch_user_repos(username : String) : Array(JSON::Any)
    all_repos = [] of JSON::Any
    page = 1
    per_page = 100

    loop do
      url = "https://api.github.com/users/#{username}/repos?page=#{page}&per_page=#{per_page}"
      response = make_github_request(url)

      if response.nil?
        Utils.print_error("Could not fetch repositories for: #{username}")
        return [] of JSON::Any
      end

      repos = JSON.parse(response)
      break if !repos.as_a? || repos.as_a.empty?

      all_repos.concat(repos.as_a)

      # If we got fewer than per_page, we've reached the end
      break if repos.as_a.size < per_page

      page += 1
    end

    all_repos
  end

  private def make_github_request(url : String) : String?
    headers = HTTP::Headers.new
    headers["Accept"] = "application/vnd.github.v3+json"
    headers["User-Agent"] = "Milka-CLI"

    # Check for GitHub token in environment
    if token = ENV["GITHUB_TOKEN"]?
      headers["Authorization"] = "token #{token}"
    elsif token = ENV["GH_TOKEN"]?
      headers["Authorization"] = "token #{token}"
    end

    response = HTTP::Client.get(url, headers: headers)

    case response.status_code
    when 200
      response.body
    when 404
      nil
    when 403
      Utils.print_warning("Rate limit may be exceeded. Set GITHUB_TOKEN environment variable for higher limits.")
      nil
    else
      Utils.print_error("GitHub API returned status: #{response.status_code}")
      nil
    end
  end

  private def parse_repo_info(repo : JSON::Any) : NamedTuple(name: String, url: String, branch: String)?
    begin
      name = repo["name"]?.try(&.as_s)
      clone_url = repo["clone_url"]?.try(&.as_s)
      default_branch = repo["default_branch"]?.try(&.as_s) || "main"

      return nil if name.nil? || clone_url.nil?

      # Use branch override if provided
      branch = @branch_override || default_branch

      {name: name, url: clone_url, branch: branch}
    rescue
      nil
    end
  end

  private def clone_repository(url : String, dir : String, branch : String) : Bool
    stdout_builder = String::Builder.new
    stderr_builder = String::Builder.new

    result = Process.run(
      "git",
      ["clone", "--branch", branch, url, dir],
      output: stdout_builder,
      error: stderr_builder
    )

    result.success?
  end
end
