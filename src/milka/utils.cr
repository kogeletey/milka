require "../milka/types/repository_info"
require "../milka/types/git_error"
require "uuid"

module Utils
  # CLI Helper Functions and Constants
  ANSI_COLORS = {
    reset:   "\033[0m",
    info:    "\033[34m", # blue
    success: "\033[32m", # green
    error:   "\033[31m", # red
    warning: "\033[33m", # yellow
  }

  def self.print_info(message : String)
    puts "#{ANSI_COLORS[:info]}#{message}#{ANSI_COLORS[:reset]}"
  end

  def self.print_success(message : String)
    puts "#{ANSI_COLORS[:success]}#{message}#{ANSI_COLORS[:reset]}"
  end

  def self.print_error(message : String)
    puts "#{ANSI_COLORS[:error]}#{message}#{ANSI_COLORS[:reset]}"
  end

  def self.print_warning(message : String)
    puts "#{ANSI_COLORS[:warning]}#{message}#{ANSI_COLORS[:reset]}"
  end

  def self.print_usage
    puts <<-USAGE
    Milka - A command-line tool for managing multiple git repositories

    Usage: milka <command> [repo-name] [options]

    Commands:
      clone [repo-name]    Clone a repository or all repositories (if no repo-name provided)
      fetch [repo-name]    Fetch updates for a repository or all repositories (if no repo-name provided)
      pull [repo-name]     Pull latest changes for a repository or all repositories (if no repo-name provided)
      push [repo-name]     Push changes for all repositories
      scan                 Scan for git repositories in the current directory and add them to reps.toml
      init                 Initialize a new reps.toml configuration file
      help                 Show this help message

    Options:
      --config <path>      Path to reps.toml configuration file (default: ./.meta/reps.toml)
      --branch <branch>    Specify branch (default: from config or main)

    Examples:
      milka clone                    Clone all repositories from reps.toml
      milka clone my-repo            Clone specific repository
      milka fetch                    Fetch updates for all repositories
      milka fetch my-repo            Fetch updates for specific repository
      milka pull                     Pull latest changes for all repositories
      milka pull my-repo             Pull latest changes for specific repository
      milka push                    Push changes for all repositories
      milka push my-repo             Push changes for specific repository
      milka scan                     Scan current directory for git repos and add to reps.toml
      milka init                     Initialize a new reps.toml configuration file
      milka --config /path/to/reps.toml clone
      milka --config /path/to/reps.toml --branch feature-branch clone my-repo
    USAGE
  end

  def self.find_repository_in(repositories : Array(RepositoryInfo), named name : String)
    repositories.find { |repo| repo.name == name }
  end
end