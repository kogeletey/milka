require "../types/repository_info"
require "../types/issue_info"
require "../types/comment_info"
require "../types/git_error"
require "../providers/issue_provider"
require "../providers/github_provider"
require "../providers/forgejo_provider"
require "../utils"
require "../config_manager"

# Command to download issues from repositories and save them as files
class IssuesCommand
  DEFAULT_OUTPUT_DIR = ".meta/issues"
  DEFAULT_FORMAT = "org"

  property config_path : String
  property branch_override : String?
  property output_format : String
  property output_dir : String
  property state_filter : String

  def initialize(
    @config_path : String,
    @branch_override : String? = nil,
    @output_format : String = DEFAULT_FORMAT,
    @output_dir : String = DEFAULT_OUTPUT_DIR,
    @state_filter : String = "all"
  )
  end

  def execute(repositories : Array(RepositoryInfo)? = nil, repo_name : String? = nil, additional_args : Array(String) = [] of String)
    # Parse additional arguments for format and state options
    parse_additional_args(additional_args)

    # Validate format
    unless ["org", "md", "json"].includes?(@output_format)
      raise GitError.new("Invalid output format '#{@output_format}'. Supported formats: org, md, json")
    end

    # Validate state filter
    unless ["open", "closed", "all"].includes?(@state_filter)
      raise GitError.new("Invalid state filter '#{@state_filter}'. Supported states: open, closed, all")
    end

    # Ensure output directory exists
    Dir.mkdir_p(@output_dir) unless Dir.exists?(@output_dir)

    if repo_name
      # Download issues for a specific repository
      download_issues_for_repo_name(repo_name, repositories)
    elsif repositories && !repositories.empty?
      # Download issues for all repositories from config
      download_issues_for_all(repositories)
    else
      Utils.print_error("No repositories specified. Either provide a repository name or ensure .meta/reps.toml has repositories configured.")
      exit(1)
    end
  end

  private def parse_additional_args(args : Array(String))
    i = 0
    while i < args.size
      arg = args[i]
      case arg
      when "--format"
        if i + 1 < args.size
          @output_format = args[i + 1]
          i += 2
          next
        end
      when "--output", "-o"
        if i + 1 < args.size
          @output_dir = args[i + 1]
          i += 2
          next
        end
      when "--state"
        if i + 1 < args.size
          @state_filter = args[i + 1]
          i += 2
          next
        end
      end
      i += 1
    end
  end

  private def download_issues_for_repo_name(repo_name : String, repositories : Array(RepositoryInfo)?)
    # First, try to find the repository in the config
    repo = repositories.try { |repos| Utils.find_repository_in(repos, named: repo_name) }

    if repo
      download_issues_for_repository(repo)
    else
      # If not in config, check if repo_name looks like a URL
      if repo_name.includes?("://") || repo_name.starts_with?("git@")
        download_issues_for_url(repo_name)
      else
        # Try to parse as owner/repo format
        if repo_name.includes?("/") && !repo_name.starts_with?("/")
          parts = repo_name.split("/", 2)
          if parts.size == 2
            download_issues_for_owner_repo(parts[0], parts[1], "https://github.com")
            return
          end
        end

        Utils.print_error("Repository '#{repo_name}' not found in configuration and is not a valid URL or owner/repo format.")
        exit(1)
      end
    end
  end

  private def download_issues_for_all(repositories : Array(RepositoryInfo))
    Utils.print_info("Downloading issues for #{repositories.size} repositories...")

    repositories.each_with_index do |repo, index|
      Utils.print_info("[#{index + 1}/#{repositories.size}] Processing #{repo.name}")
      begin
        download_issues_for_repository(repo)
      rescue e : GitError
        Utils.print_warning("  Skipping #{repo.name}: #{e.message}")
      end
    end
  end

  private def download_issues_for_repository(repo : RepositoryInfo)
    parsed = IssueProvider.parse_repo_url(repo.url)
    unless parsed
      raise GitError.new("Could not parse repository URL: #{repo.url}")
    end

    owner, repo_name = parsed
    base_url = IssueProvider.extract_base_url(repo.url)

    provider = create_provider_for_url(repo.url, base_url)
    fetch_and_save_issues(provider, owner, repo_name, repo.name)
  end

  private def download_issues_for_url(url : String)
    parsed = IssueProvider.parse_repo_url(url)
    unless parsed
      raise GitError.new("Could not parse repository URL: #{url}")
    end

    owner, repo_name = parsed
    base_url = IssueProvider.extract_base_url(url)

    provider = create_provider_for_url(url, base_url)
    fetch_and_save_issues(provider, owner, repo_name, repo_name)
  end

  private def download_issues_for_owner_repo(owner : String, repo : String, base_url : String)
    provider = GitHubIssueProvider.new
    fetch_and_save_issues(provider, owner, repo, repo)
  end

  private def create_provider_for_url(url : String, base_url : String?) : IssueProvider
    provider_type = IssueProvider.detect_provider_type(url)

    case provider_type
    when "github"
      GitHubIssueProvider.new
    when "forgejo"
      ForgejoIssueProvider.new(base_url || "https://codeberg.org")
    else
      # Default to GitHub for unknown providers
      GitHubIssueProvider.new
    end
  end

  private def fetch_and_save_issues(provider : IssueProvider, owner : String, repo : String, local_name : String)
    Utils.print_info("  Fetching issues from #{provider.name} (#{owner}/#{repo})...")

    issues = provider.fetch_issues(owner, repo, @state_filter)

    if issues.empty?
      Utils.print_info("  No issues found.")
      return
    end

    Utils.print_info("  Found #{issues.size} issues. Saving...")

    # Create a subdirectory for each repository
    repo_issues_dir = File.join(@output_dir, local_name)
    Dir.mkdir_p(repo_issues_dir) unless Dir.exists?(repo_issues_dir)

    saved_count = 0
    issues.each do |issue|
      filename = "#{issue.number}.#{@output_format}"
      filepath = File.join(repo_issues_dir, filename)

      content = case @output_format
                when "md"
                  issue.to_md
                when "json"
                  issue.to_json_ld
                else
                  issue.to_org
                end

      begin
        File.write(filepath, content)
        saved_count += 1
      rescue e
        Utils.print_warning("  Failed to save issue ##{issue.number}: #{e.message}")
      end
    end

    Utils.print_success("  Saved #{saved_count} issues to #{repo_issues_dir}/")
  end
end
