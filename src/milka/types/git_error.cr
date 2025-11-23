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