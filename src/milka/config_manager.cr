require "toml"
require "../milka/types/repository_info"
require "../milka/types/mise_config"
require "../milka/types/git_error"
require "./utils"

class MilkaRclParser
  alias Token = NamedTuple(kind: String, value: String)

  @tokens : Array(Token)
  @position : Int32

  def initialize(content : String)
    @tokens = tokenize(content)
    @position = 0
  end

  def repositories : Array(Hash(String, String))
    expect_word("do")
    repos = parse_repo_array
    expect_kind("eof")
    repos
  end

  private def tokenize(content : String) : Array(Token)
    tokens = [] of Token
    index = 0

    while index < content.size
      char = content[index]

      if char.whitespace?
        index += 1
      elsif char == '#'
        index += 1
        while index < content.size && content[index] != '\n'
          index += 1
        end
      elsif char == '[' || char == ']' || char == '=' || char == ','
        tokens << {kind: char.to_s, value: char.to_s}
        index += 1
      elsif char == '"'
        value, index = read_string(content, index + 1)
        tokens << {kind: "string", value: value}
      elsif identifier_start?(char)
        start = index
        index += 1
        while index < content.size && identifier_part?(content[index])
          index += 1
        end
        tokens << {kind: "word", value: content[start...index]}
      else
        raise "Unexpected character '#{char}'"
      end
    end

    tokens << {kind: "eof", value: ""}
    tokens
  end

  private def read_string(content : String, index : Int32) : {String, Int32}
    value = String::Builder.new

    while index < content.size
      char = content[index]

      if char == '"'
        return {value.to_s, index + 1}
      elsif char == '\\'
        index += 1
        raise "Unterminated string" if index >= content.size

        escaped = content[index]
        case escaped
        when '"', '\\'
          value << escaped
        when 'n'
          value << '\n'
        when 'r'
          value << '\r'
        when 't'
          value << '\t'
        else
          value << escaped
        end
      else
        value << char
      end

      index += 1
    end

    raise "Unterminated string"
  end

  private def identifier_start?(char : Char) : Bool
    char.ascii_letter? || char == '_'
  end

  private def identifier_part?(char : Char) : Bool
    char.ascii_letter? || char.ascii_number? || char == '_' || char == '-' || char == '.' || char == '+'
  end

  private def parse_repo_array : Array(Hash(String, String))
    repos = [] of Hash(String, String)
    expect_kind("[")

    until current["kind"] == "]"
      expect_word("do")
      repos << parse_repo_properties
      expect_word("end")
      accept_kind(",")
    end

    expect_kind("]")
    repos
  end

  private def parse_repo_properties : Hash(String, String)
    repo = {} of String => String

    until current_word?("end")
      key = expect_word
      expect_kind("=")
      repo[key] = parse_value
    end

    repo
  end

  private def parse_value : String
    if value = accept_kind("string")
      value
    else
      expect_word
    end
  end

  private def current : Token
    @tokens[@position]
  end

  private def current_word?(value : String) : Bool
    current["kind"] == "word" && current["value"] == value
  end

  private def accept_word(value : String) : Bool
    return false unless current_word?(value)

    advance
    true
  end

  private def accept_kind(kind : String) : String?
    return nil unless current["kind"] == kind

    value = current["value"]
    advance
    value
  end

  private def expect_word : String
    raise "Expected identifier, got #{current["kind"]}" unless current["kind"] == "word"

    value = current["value"]
    advance
    value
  end

  private def expect_word(value : String)
    actual = expect_word
    raise "Expected '#{value}', got '#{actual}'" unless actual == value
  end

  private def expect_kind(kind : String)
    raise "Expected '#{kind}', got #{current["kind"]}" unless current["kind"] == kind

    advance
  end

  private def advance
    @position += 1
  end
end

class ConfigManager
  def self.load_mise_config(path : String) : MiseConfig
    unless File.exists?(path)
      raise GitError.config_file_not_found("Configuration file not found at: #{path}")
    end

    repositories = config_format(path) == :rcl ? load_rcl_repositories(path) : load_toml_repositories(path)

    if repositories.empty?
      Utils.print_warning("No repositories found in config. Ensure the config uses [[repo]] in TOML or root-array do [...] in RCL with 'dir' and 'remote' keys.")
    end

    MiseConfig.new(repositories, "main", nil)
  rescue e : File::NotFoundError
    raise GitError.config_file_not_found("Configuration file not found at: #{path}")
  end

  private def self.config_format(path : String) : Symbol
    extension = File.extname(path).downcase
    return :rcl if extension == ".rcl"
    return :toml if extension == ".toml"
    return :toml unless File.exists?(path)

    content = File.read(path)
    looks_like_rcl?(content) ? :rcl : :toml
  end

  private def self.looks_like_rcl?(content : String) : Bool
    content.each_line do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.starts_with?("#")

      return stripped.starts_with?("do [")
    end

    false
  end

  private def self.load_toml_repositories(path : String) : Array(RepositoryInfo)
    repositories = [] of RepositoryInfo
    content = File.read(path)

    begin
      toml_data = TOML.parse(content)
      return repositories unless toml_data.has_key?("repo")

      each_toml_repo_hash(toml_data["repo"]) do |repo_hash|
        repositories << repository_from_toml_hash(repo_hash)
      end
    rescue e : TOML::ParseException
      raise GitError.config_file_invalid("Invalid TOML format: #{e.message}")
    end

    repositories
  end

  private def self.each_toml_repo_hash(repo_data, & : Hash(String, TOML::Any) ->)
    case repo_data
    when Array
      repo_data.each do |item|
        yield toml_repo_hash(item)
      end
    when TOML::Any
      if repo_array = repo_data.as_a?
        repo_array.each do |item|
          yield toml_repo_hash(item)
        end
      else
        yield repo_data.as_h
      end
    else
      raise GitError.config_file_invalid("Unexpected 'repo' data type: #{repo_data.class}")
    end
  end

  private def self.toml_repo_hash(item) : Hash(String, TOML::Any)
    if item.is_a?(Hash)
      item
    elsif item.is_a?(TOML::Any)
      item.as_h? || raise GitError.config_file_invalid("Repository entry is not a valid object: #{item}")
    else
      raise GitError.config_file_invalid("Unexpected repository data type: #{item.class}")
    end
  end

  private def self.repository_from_toml_hash(repo_hash : Hash(String, TOML::Any)) : RepositoryInfo
    name = repo_hash["dir"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
    url = repo_hash["remote"]?.try(&.as_s) || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
    branch = repo_hash["branch"]?.try(&.as_s) || "main"
    commit = repo_hash["commit"]?.try(&.as_s) || ""
    source = repo_hash["source"]?.try(&.as_s) || "git"

    RepositoryInfo.new(name, url, branch, commit, source)
  end

  private def self.load_rcl_repositories(path : String) : Array(RepositoryInfo)
    repositories = [] of RepositoryInfo
    content = File.read(path)
    return repositories if content.strip.empty?

    begin
      MilkaRclParser.new(content).repositories.each do |repo_hash|
        repositories << repository_from_rcl_hash(repo_hash)
      end
    rescue e
      raise GitError.config_file_invalid("Invalid RCL format: #{e.message}")
    end

    repositories
  end

  private def self.repository_from_rcl_hash(repo_hash : Hash(String, String)) : RepositoryInfo
    name = repo_hash["dir"]? || raise GitError.config_file_invalid("Repository configuration missing 'dir' field")
    url = repo_hash["remote"]? || raise GitError.config_file_invalid("Repository configuration missing 'remote' field")
    branch = repo_hash["branch"]? || "main"
    commit = repo_hash["commit"]? || ""
    source = repo_hash["source"]? || "git"

    RepositoryInfo.new(name, url, branch, commit, source)
  end

  def self.get_git_remote_info(git_dir : String) : String?
    begin
      # Execute git remote -v to get the remote URLs
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["remote", "-v"],
        output: stdout_builder,
        error: stderr_builder,
        chdir: git_dir
      )

      if result.success?
        output = stdout_builder.to_s
        # Parse the output to find the origin remote
        output.each_line do |line|
          if line.includes?("origin") && line.includes?("(fetch)")
            # Extract the URL from the line like: origin	https://github.com/user/repo.git (fetch)
            parts = line.split(/\s+/)
            if parts.size >= 2
              return parts[1]
            end
          end
        end
      end
    rescue
      # If there's an error running git command, return nil
    end

    nil
  end

  def self.get_git_branch(git_dir : String) : String
    begin
      stdout_builder = String::Builder.new
      stderr_builder = String::Builder.new

      result = Process.run(
        "git",
        ["rev-parse", "--abbrev-ref", "HEAD"],
        output: stdout_builder,
        error: stderr_builder,
        chdir: git_dir
      )

      if result.success?
        branch = stdout_builder.to_s.strip
        return branch unless branch.empty?
      else
        # Check if the error is because HEAD doesn't exist (no commits yet)
        stderr_output = stderr_builder.to_s
        if stderr_output.includes?("HEAD") && stderr_output.includes?("unknown revision")
          # If HEAD doesn't exist, default to main
          return "main"
        end
      end
    rescue
      # If there's an error, return default branch
    end

    "main" # Default branch
  end

  def self.repo_exists_in_config(config_path : String, dir_name : String) : Bool
    return false unless File.exists?(config_path)

    begin
      return load_mise_config(config_path).repositories.any? { |repo| repo.name == dir_name }
    rescue
      # If there's an error parsing the config, return false
    end

    false
  end

  def self.add_git_repo_to_config(config_path : String, dir_name : String, remote_url : String, branch : String, source : String = "git")
    # Create the directory if it doesn't exist
    config_dir = File.dirname(config_path)
    Dir.mkdir_p(config_dir) unless File.directory?(config_dir)

    if config_format(config_path) == :rcl
      add_git_repo_to_rcl_config(config_path, dir_name, remote_url, branch, source)
      return
    end

    # Check if the repository already exists in the config
    return if repo_exists_in_config(config_path, dir_name)

    new_entry = toml_repo_entry(dir_name, remote_url, branch, source)

    # Append the new entry to the config file
    File.open(config_path, "a") do |file|
      file.puts(new_entry)
    end
  end

  private def self.add_git_repo_to_rcl_config(config_path : String, dir_name : String, remote_url : String, branch : String, source : String)
    repositories = File.exists?(config_path) ? load_mise_config(config_path).repositories : [] of RepositoryInfo
    return if repositories.any? { |repo| repo.name == dir_name }

    repositories << RepositoryInfo.new(dir_name, remote_url, branch, "", source)
    File.write(config_path, rcl_config_content(repositories))
  rescue e : GitError
    raise e
  end

  private def self.toml_repo_entry(dir_name : String, remote_url : String, branch : String, source : String) : String
    new_entry = "\n[[repo]]\n"
    new_entry += "dir = '#{dir_name}'\n"
    new_entry += "remote = '#{remote_url}'\n"
    new_entry += "branch = '#{branch}'\n"
    new_entry += "source = '#{source}'\n\n" if source != "git"
    new_entry
  end

  private def self.rcl_repo_entry(dir_name : String, remote_url : String, branch : String, source : String) : String
    lines = [
      "  do",
      "    dir = #{rcl_quote(dir_name)}",
      "    remote = #{rcl_quote(remote_url)}",
      "    branch = #{rcl_quote(branch)}",
    ]
    lines << "    source = #{rcl_quote(source)}" if source != "git"
    lines << "  end"
    lines.join("\n")
  end

  private def self.rcl_config_content(repositories : Array(RepositoryInfo)) : String
    entries = repositories.map do |repo|
      rcl_repo_entry(repo.name, repo.url, repo.branch, repo.source)
    end

    <<-RCL
    # Milka - Repository Configuration
    do [
    #{entries.join(",\n")}
    ]
    RCL
  end

  private def self.rcl_quote(value : String) : String
    value.inspect
  end

  def self.scan_git_directories(root_path : String = ".") : Array(String)
    git_directories = [] of String

    Dir.glob("#{root_path}/**/*").each do |path|
      next unless File.directory?(path)

      git_path = File.join(path, ".git")
      if File.directory?(git_path)
        # Get the directory name (last component of path)
        dir_name = File.basename(path)
        git_directories << path
      end
    end

    git_directories
  end
end
