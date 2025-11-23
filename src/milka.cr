require "toml"

# Data structures
class RepositoryInfo
  property name : String
  property url : String
  property branch : String
  property latest_commit : String
  property local_path : String

  def initialize(@name : String, @url : String, @branch : String = "main", @latest_commit : String = "")
    @local_path = name
  end
end

class MiseConfig
  property repositories : Array(RepositoryInfo)
  property default_branch : String
  property env : Hash(String, String)?

  def initialize(@repositories : Array(RepositoryInfo), @default_branch : String, @env : Hash(String, String)?)
  end
end

# Exception classes
class GitError < Exception
  def self.clone_failed(message)
    new("Clone failed: #{message}")
  end

  def self.fetch_failed(message)
    new("Fetch failed: #{message}")
  end

  def self.pull_failed(message)
    new("Pull failed: #{message}")
  end

  def self.push_failed(message)
    new("Push failed: #{message}")
  end

  def self.config_file_not_found(message)
    new("Config file not found: #{message}")
  end

  def self.config_file_invalid(message)
    new("Config file invalid: #{message}")
  end

  def self.authentication_required(message)
    new("Authentication required: #{message}. Please provide a username/password or use a personal access token for private repositories.")
  end
end


