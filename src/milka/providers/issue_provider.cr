require "../types/issue_info"
require "../types/git_error"

# Abstract base class for issue providers (GitHub, Forgejo, etc.)
# This allows for extensibility - new providers can be added by inheriting from this class
abstract class IssueProvider
  # Fetch issues from the provider
  # @param owner - repository owner
  # @param repo - repository name
  # @param state - "open", "closed", or "all"
  # @return Array of IssueInfo objects
  abstract def fetch_issues(owner : String, repo : String, state : String = "all") : Array(IssueInfo)

  # Get the provider name (for display purposes)
  abstract def name : String

  # Parse a repository URL to extract owner and repo
  # @return Tuple of (owner, repo) or nil if cannot be parsed
  def self.parse_repo_url(url : String) : {String, String}?
    # GitHub format: https://github.com/owner/repo[.git]
    # Forgejo format: https://codeberg.org/owner/repo[.git] (or any host)
    # SSH format: git@github.com:owner/repo.git

    # Handle SSH format
    if url.starts_with?("git@")
      # git@github.com:owner/repo.git
      if match = url.match(/git@[^:]+:([^\/]+)\/([^\.]+)(\.git)?$/)
        return {match[1], match[2]}
      end
    end

    # Handle HTTPS format
    if url.includes?("://")
      # Remove trailing .git if present
      clean_url = url.gsub(/\.git$/, "")
      # Extract path after domain
      if match = clean_url.match(/https?:\/\/[^\/]+\/([^\/]+)\/([^\/\?#]+)/)
        return {match[1], match[2]}
      end
    end

    nil
  end

  # Detect provider type from URL
  def self.detect_provider_type(url : String) : String
    if url.includes?("github.com")
      "github"
    elsif url.includes?("codeberg.org") || url.includes?("gitea") || url.includes?("forgejo")
      "forgejo"
    else
      # Default to forgejo for generic git hosts (since it uses a common API)
      "forgejo"
    end
  end

  # Extract the base URL (host) from a repository URL
  def self.extract_base_url(url : String) : String?
    if url.starts_with?("git@")
      # git@github.com:owner/repo.git -> github.com
      if match = url.match(/git@([^:]+):/)
        return "https://#{match[1]}"
      end
    end

    if match = url.match(/(https?:\/\/[^\/]+)/)
      return match[1]
    end

    nil
  end
end
