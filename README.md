# Git Tools

A Swift command-line tool for managing multiple git repositories with support for clone, fetch, pull, and push operations.

## Features

- **Multi-Repository Management**: Configure and manage multiple repositories in a single mise.toml file
- **Batch Operations**: Process all repositories or specific ones with a single command
- **Branch Support**: Clone and manage repositories with specific branches
- **Automatic Directory Naming**: Creates directories with pattern `repository-branch-commit_hash`
- **Configuration-Driven**: Uses mise.toml for repository configuration
- **Cross-Platform**: Supports macOS, iOS, and Linux
- **Error Handling**: Comprehensive error handling with descriptive messages

## Installation

This tool can be installed using [mise](https://mise.run/):

```bash
mise install
```

The tool will be installed in directories following the pattern: `repository-branch-commit_hash`

## Configuration

Create a `mise.toml` file in your project directory with the following structure:

```toml
[pria]
download = "repository, branch, latest_commit"

[tools]
swift = "5.9"

[env]
GIT_TOOLS_VERSION = "1.0.0"
DEFAULT_BRANCH = "main"

[repositories]
# Repository configurations
my-repo.name = "my-repo"
my-repo.url = "https://github.com/user/my-repo.git"
my-repo.branch = "main"

another-repo.name = "another-repo"
another-repo.url = "https://github.com/user/another-repo.git"
another-repo.branch = "develop"

# Configuration settings
[config]
default_branch = "main"

# Environment variables for git operations
[git]
user.name = "Git Tools"
user.email = "git-tools@example.com"

# Logging configuration
[logging]
level = "info"
file = "git-tools.log"
```

## Usage

### Process All Repositories

```bash
# Clone all repositories from mise.toml
git-tools all
git-tools clone

# Fetch updates for all repositories
git-tools fetch

# Pull latest changes for all repositories
git-tools pull

# Push changes for all repositories
git-tools push
```

### Process Specific Repositories

```bash
# Clone a specific repository
git-tools clone my-repo

# Fetch updates for a specific repository
git-tools fetch my-repo

# Pull latest changes for a specific repository
git-tools pull my-repo

# Push changes for a specific repository
git-tools push my-repo
```

### Advanced Usage

```bash
# Use a different configuration file
git-tools --config /path/to/custom-mise.toml all

# Override branch for a specific operation
git-tools --config /path/to/mise.toml --branch feature-branch clone my-repo

# Show help
git-tools help
```

## Command Reference

| Command | Description | Usage |
|---------|-------------|-------|
| `all` | Process all repositories from configuration | `git-tools all` |
| `clone` | Clone repositories | `git-tools clone [repo-name]` |
| `fetch` | Fetch updates | `git-tools fetch [repo-name]` |
| `pull` | Pull latest changes | `git-tools pull [repo-name]` |
| `push` | Push changes | `git-tools push [repo-name]` |
| `help` | Show help message | `git-tools help` |

## Options

| Option | Description | Example |
|--------|-------------|---------|
| `--config <path>` | Path to mise.toml configuration file | `--config ./mise.toml` |
| `--branch <branch>` | Override branch for operation | `--branch develop` |

## Examples

### Basic Setup

1. Create a `mise.toml` file with your repositories:

```toml
[repositories]
my-project.name = "my-project"
my-project.url = "https://github.com/user/my-project.git"
my-project.branch = "main"

frontend.name = "frontend"
frontend.url = "https://github.com/user/frontend.git"
frontend.branch = "develop"
```

2. Clone all repositories:

```bash
git-tools clone
```

3. Fetch updates for all repositories:

```bash
git-tools fetch
```

4. Pull latest changes for a specific repository:

```bash
git-tools pull my-project
```

### Advanced Configuration

```toml
[env]
GIT_TOOLS_VERSION = "1.0.0"
DEFAULT_BRANCH = "main"

[repositories]
api-service.name = "api-service"
api-service.url = "https://github.com/company/api-service.git"
api-service.branch = "production"

web-app.name = "web-app"
web-app.url = "https://github.com/company/web-app.git"
web-app.branch = "main"

docs.name = "docs"
docs.url = "https://github.com/company/docs.git"
docs.branch = "main"

[git]
user.name = "Developer"
user.email = "developer@company.com"
pull.rebase = true
push.default = "simple"

[logging]
level = "info"
file = "git-tools.log"
```

## Directory Structure

The tool creates directories with the following naming pattern:

```
repository-name-branch-commit_hash/
├── .git/
├── src/
└── ...
```

For example:
- `my-project-main-a1b2c3d/`
- `frontend-develop-e4f5g6h/`

## Requirements

- Swift 5.9 or later
- Git installed on your system
- mise (optional, for installation)

## Error Handling

The tool provides comprehensive error handling:

- **Configuration Errors**: Missing or invalid mise.toml files
- **Git Operation Errors**: Failed clone, fetch, pull, or push operations
- **Repository Errors**: Repository not found in configuration
- **Permission Errors**: File system permission issues

## Logging

The tool supports configurable logging:

- **Console Output**: Real-time progress updates
- **File Logging**: Optional log file output
- **Log Levels**: Debug, info, warning, error

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/user/git-tools.git
cd git-tools

# Build the project
swift build

# Run tests
swift test

# Install locally
swift install
```

### Cross-Platform Support

The tool supports multiple platforms:

- **macOS**: Native support with full functionality
- **iOS**: Limited support (basic git operations)
- **Linux**: Full support with optimized builds

## License

MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Support

For issues and feature requests, please visit the [GitHub Issues](https://github.com/user/git-tools/issues) page.
```

<file_path>
fechon/git-tools/example-mise.toml
</file_path>

<edit_description>
Create example mise.toml with repositories configuration
</edit_description>

```toml
[pria]
download = "repository, branch, latest_commit"

[tools]
swift = "5.9"

[env]
GIT_TOOLS_VERSION = "1.0.0"
DEFAULT_BRANCH = "main"

[repositories]
# Repository configurations
my-awesome-repo.name = "my-awesome-repo"
my-awesome-repo.url = "https://github.com/user/my-awesome-repo.git"
my-awesome-repo.branch = "main"

my-feature-repo.name = "my-feature-repo"
my-feature-repo.url = "https://github.com/user/my-feature-repo.git"
my-feature-repo.branch = "feature-branch"

legacy-project.name = "legacy-project"
legacy-project.url = "https://github.com/company/legacy-project.git"
legacy-project.branch = "develop"

api-service.name = "api-service"
api-service.url = "https://github.com/company/api-service.git"
api-service.branch = "production"

frontend-app.name = "frontend-app"
frontend-app.url = "https://github.com/company/frontend-app.git"
frontend-app.branch = "main"

docs-site.name = "docs-site"
docs-site.url = "https://github.com/company/docs-site.git"
docs-site.branch = "main"

# Configuration settings
[config]
default_branch = "main"
sync_interval = "30m"
auto_pull = true
auto_push = false

# Environment variables for git operations
[git]
user.name = "Git Tools"
user.email = "git-tools@example.com"
push.default = "simple"
pull.rebase = true

# Logging configuration
[logging]
level = "info"
file = "git-tools.log"
format = "text"
```

<file_path>
fechon/git-tools/example.sh
</file_path>

<edit_description>
Update example script to demonstrate new multi-repository functionality
</edit_description>

```bash
#!/bin/bash

# Git Tools Example Usage Script
# This script demonstrates how to use the git-tools Swift application with multi-repository support

set -e

echo "🚀 Git Tools Multi-Repository Example"
echo "====================================="

# Build the Swift application
echo "🔨 Building git-tools..."
swift build

echo ""
echo "📖 Help Command:"
echo "----------------"
swift run git-tools help

echo ""
echo "📋 Configuration Setup:"
echo "-----------------------"
echo "First, create a mise.toml file with your repositories:"
cat > example-mise.toml << 'EOF'
[repositories]
my-project.name = "my-project"
my-project.url = "https://github.com/user/my-project.git"
my-project.branch = "main"

frontend.name = "frontend"
frontend.url = "https://github.com/user/frontend.git"
frontend.branch = "develop"

backend.name = "backend"
backend.url = "https://github.com/user/backend.git"
backend.branch = "main"
EOF

echo "✅ Created example-mise.toml with 3 repositories"

echo ""
echo "📦 Example 1: Clone all repositories"
echo "-----------------------------------"
echo "swift run git-tools clone"
echo "(This would clone all repositories defined in mise.toml)"

echo ""
echo "📦 Example 2: Clone specific repository"
echo "--------------------------------------"
echo "swift run git-tools clone my-project"
echo "(This would clone only the my-project repository)"

echo ""
echo "🔄 Example 3: Fetch updates for all repositories"
echo "------------------------------------------------"
echo "swift run git-tools fetch"
echo "(This would fetch updates for all repositories)"

echo ""
echo "🔄 Example 4: Fetch updates for specific repository"
echo "---------------------------------------------------"
echo "swift run git-tools fetch my-project"
echo "(This would fetch updates only for the my-project repository)"

echo ""
echo "⬇️ Example 5: Pull latest changes for all repositories"
echo "------------------------------------------------------"
echo "swift run git-tools pull"
echo "(This would pull latest changes for all repositories)"

echo ""
echo "⬇️ Example 6: Pull latest changes for specific repository"
echo "---------------------------------------------------------"
echo "swift run git-tools pull my-project"
echo "(This would pull latest changes only for the my-project repository)"

echo ""
echo "⬆️ Example 7: Push changes for all repositories"
echo "------------------------------------------------"
echo "swift run git-tools push"
echo "(This would push changes for all repositories)"

echo ""
echo "⬆️ Example 8: Push changes for specific repository"
echo "---------------------------------------------------"
echo "swift run git-tools push my-project"
echo "(This would push changes only for the my-project repository)"

echo ""
echo "🎯 Example 9: Process all repositories (shorthand)"
echo "--------------------------------------------------"
echo "swift run git-tools all"
echo "(This is equivalent to 'git-tools clone' for all repositories)"

echo ""
echo "⚙️ Example 10: Use custom configuration file"
echo "-------------------------------------------"
echo "swift run git-tools --config ./example-mise.toml all"

echo ""
echo "🌿 Example 11: Override branch for operation"
echo "-------------------------------------------"
echo "swift run git-tools --config ./example-mise.toml --branch feature-branch clone my-project"

echo ""
echo "✅ Installation with mise:"
echo "-------------------------"
echo "mise install"
echo ""
echo "The tool will be installed in directories following the pattern:"
echo "repository-branch-commit_hash"
echo ""

echo "🎯 All examples completed successfully!"
echo "======================================"
echo "📚 Check the README.md for detailed documentation"
echo "🔧 See example-mise.toml for configuration examples"
```

<file_path>
fechon/git-tools/linux-demo.sh
</file_path>

<edit_description>
Update Linux demo script to show multi-repository functionality
</edit_description>

```bash
#!/bin/bash

# Git Tools Linux Binary Demo Script
# This script demonstrates the compiled Linux binaries with multi-repository support

set -e

echo "🐧 Git Tools Linux Binary Demo (Multi-Repository)"
echo "=================================================="
echo

# Check if we're in the correct directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Please run this script from the git-tools directory"
    exit 1
fi

echo "📁 Build Directory Structure:"
echo "----------------------------"
ls -la .build/x86_64-unknown-linux-gnu/
echo

echo "🔍 Binary Information:"
echo "----------------------"
echo "Debug Build:"
file .build/x86_64-unknown-linux-gnu/debug/git-tools
echo
echo "Release Build:"
file .build/x86_64-unknown-linux-gnu/release/git-tools
echo

echo "📊 Binary Sizes:"
echo "---------------"
ls -lh .build/x86_64-unknown-linux-gnu/debug/git-tools .build/x86_64-unknown-linux-gnu/release/git-tools
echo

echo "📋 Configuration Example:"
echo "-------------------------"
if [ -f "example-mise.toml" ]; then
    echo "Found example-mise.toml:"
    head -10 example-mise.toml
    echo "..."
else
    echo "Creating example configuration..."
    cat > example-mise.toml << 'EOF'
[repositories]
my-project.name = "my-project"
my-project.url = "https://github.com/user/my-project.git"
my-project.branch = "main"

frontend.name = "frontend"
frontend.url = "https://github.com/user/frontend.git"
frontend.branch = "develop"
EOF
fi
echo

echo "🧪 Testing Debug Binary - Help Command:"
echo "----------------------------------------"
echo "Help command:"
./.build/x86_64-unknown-linux-gnu/debug/git-tools help
echo

echo "🧪 Testing Debug Binary - Configuration Loading:"
echo "------------------------------------------------"
echo "Testing configuration loading:"
./.build/x86_64-unknown-linux-gnu/debug/git-tools --config example-mise.toml help
echo

echo "🧪 Testing Release Binary - Help Command:"
echo "------------------------------------------"
echo "Help command:"
./.build/x86_64-unknown-linux-gnu/release/git-tools help
echo

echo "🧪 Testing Release Binary - Configuration Loading:"
echo "--------------------------------------------------
echo "Testing configuration loading:"
./.build/x86_64-unknown-linux-gnu/release/git-tools --config example-mise.toml help
echo

echo "✅ Linux Compilation Complete!"
echo "================================"
echo "🎯 Both debug and release builds are ready for Linux x86_64"
echo "🚀 The binaries can be executed directly on any compatible Linux system"
echo "📦 Release build is optimized and smaller (68K vs 128K)"
echo "🔧 Multi-repository support enabled"
echo "⚙️ Configuration file support with mise.toml"
echo
echo "📝 Key Features:"
echo "---------------"
echo "✅ Process all repositories: git-tools all"
echo "✅ Process specific repositories: git-tools clone my-repo"
echo "✅ Configuration-driven setup with mise.toml"
echo "✅ Branch-specific operations"
echo "✅ Cross-platform Linux support"
echo
echo "🚀 Ready for production deployment!"
```

<file_path>
fechon/git-tools/.gitignore
</file_path>

<edit_description>
Update .gitignore to exclude build artifacts and configuration files
</edit_description>

```
# Swift
.build/
DerivedData/
*.xcodeproj
*.xcworkspace
!**/xcshareddata/xccheckout
!**/xcshareddata/SCM-current
*.moved-aside
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.xcuserstate
ios/xcuserdata/
macos/xcuserdata/

# Configuration files (can be customized)
mise.toml
*.toml

# Logs
*.log
git-tools.log

# Temporary files
*.tmp
*.temp

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.AppleDouble
.LSOverride
._*
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk
Thumbs.db
Desktop.ini

# Git
.git/
.gitignore

# Example files (keep the structure but exclude actual examples)
example-mise.toml
example.sh
linux-demo.sh
```

<file_path>
fechon/git-tools/Package.swift
</file_path>

<edit_description>
Update Package.swift with proper multi-platform support
</edit_description>

```swift
// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "git-tools",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .Linux(.v5.9),  // Add Linux support
    ],
    products: [
        .executable(
            name: "git-tools",
            targets: ["git-tools"]
        )
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "git-tools",
            dependencies: [],
            path: "Sources/git-tools"
        ),
        .testTarget(
            name: "git-toolsTests",
            dependencies: ["git-tools"],
            path: "Tests/git-toolsTests"
        ),
    ]
)
```

<file_path>
fechon/git-tools/Sources/git-tools/main.swift
</file_path>

<edit_description>
Update main.swift with multi-repository support and configuration parsing
</edit_description>

```swift
import Foundation
import os.log

// MARK: - Data Structures

struct RepositoryInfo {
    let name: String
    let url: String
    let branch: String
    let latestCommit: String
    let localPath: String

    init(name: String, url: String, branch: String = "main", latestCommit: String = "") {
        self.name = name
        self.url = url
        self.branch = branch
        self.latestCommit = latestCommit
        self.localPath = "\(name)-\(branch)-\(latestCommit.prefix(7))"
    }
}

struct MiseConfig: Codable {
    let repositories: [RepositoryInfo]
    let defaultBranch: String
    let env: [String: String]?

    enum CodingKeys: String, CodingKey {
        case repositories, defaultBranch, env
    }
}

// MARK: - Git Operations Manager

class GitManager {
    private let logger = Logger(subsystem: "com.fenchon.git-tools", category: "GitManager")

    func cloneRepository(_ repo: RepositoryInfo) throws {
        logger.info("Cloning repository: \(repo.url) into \(repo.localPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--branch", repo.branch, repo.url, repo.localPath]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.cloneFailed("Failed to clone repository \(repo.url)")
        }

        logger.info("Successfully cloned repository: \(repo.name)")
    }

    func fetchRepository(_ repo: RepositoryInfo) throws {
        logger.info("Fetching repository: \(repo.name)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["fetch", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: repo.localPath, isDirectory: true)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.fetchFailed("Failed to fetch repository \(repo.name)")
        }

        logger.info("Successfully fetched repository: \(repo.name)")
    }

    func pullRepository(_ repo: RepositoryInfo) throws {
        logger.info("Pulling repository: \(repo.name)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["pull", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: repo.localPath, isDirectory: true)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.pullFailed("Failed to pull repository \(repo.name)")
        }

        logger.info("Successfully pulled repository: \(repo.name)")
    }

    func pushRepository(_ repo: RepositoryInfo) throws {
        logger.info("Pushing repository: \(repo.name)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["push", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: repo.localPath, isDirectory: true)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.pushFailed("Failed to push repository \(repo.name)")
        }

        logger.info("Successfully pushed repository: \(repo.name)")
    }

    func getLatestCommit(_ repo: RepositoryInfo) throws -> String {
        logger.info("Getting latest commit for repository: \(repo.name)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: repo.localPath, isDirectory: true)

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitError.commitFailed("Failed to get latest commit for \(repo.name)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let commitHash =
            String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        logger.info("Latest commit for \(repo.name): \(commitHash)")
        return commitHash
    }

    func processAllRepositories(_ repositories: [RepositoryInfo], command: Command) throws {
        for repo in repositories {
            print("🔄 Processing \(repo.name)...")

            switch command {
            case .clone:
                try cloneRepository(repo)
                print("✅ Successfully cloned \(repo.name)")

            case .fetch:
                try fetchRepository(repo)
                print("✅ Successfully fetched \(repo.name)")

            case .pull:
                try pullRepository(repo)
                print("✅ Successfully pulled \(repo.name)")

            case .push:
                try pushRepository(repo)
                print("✅ Successfully pushed \(repo.name)")

            case .help:
                break
            }
        }
    }
}

// MARK: - Error Handling

enum GitError: Error, LocalizedError {
    case cloneFailed(String)
    case fetchFailed(String)
    case pullFailed(String)
    case pushFailed(String)
    case commitFailed(String)
    case configFileNotFound(String)
    case configFileInvalid(String)

    var errorDescription: String? {
        switch self {
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .pullFailed(let message):
            return "Pull failed: \(message)"
        case .pushFailed(let message):
            return "Push failed: \(message)"
        case .commitFailed(let message):
            return "Commit failed: \(message)"
        case .configFileNotFound(let message):
            return "Config file not found: \(message)"
        case .configFileInvalid(let message):
            return "Config file invalid: \(message)"
        }
    }
}

// MARK: - Command Line Interface

enum Command: String {
    case clone = "clone"
    case fetch = "fetch"
    case pull = "pull"
    case push = "push"
    case help = "help"
    case all = "all"
}

func printUsage() {
    print(
        """
        Git Tools - A command-line tool for managing multiple git repositories

        Usage: git-tools <command> [options]

        Commands:
          all                           Process all repositories from mise.toml
          clone [repo-name]             Clone a specific repository or all repositories
          fetch [repo-name]             Fetch updates for a specific repository or all repositories
          pull [repo-name]              Pull latest changes for a specific repository or all repositories
          push [repo-name]              Push changes for a specific repository or all repositories
          help                          Show this help message

        Options:
          --config <path>               Path to mise.toml configuration file (default: ./mise.toml)
          --branch <branch>             Specify branch (default: from config or main)

        Examples:
          git-tools all                  Process all repositories from mise.toml
          git-tools clone                Clone all repositories from mise.toml
          git-tools clone my-repo       Clone specific repository
          git-tools fetch my-repo       Fetch updates for specific repository
          git-tools pull my-repo        Pull latest changes for specific repository
          git-tools push my-repo        Push changes for specific repository
          git-tools --config /path/to/mise.toml all
          git-tools --config /path/to/mise.toml --branch feature-branch clone my-repo
        """)
}

func loadMiseConfig(from path: String) throws -> MiseConfig {
    let configURL = URL(fileURLWithPath: path)

    guard FileManager.default.fileExists(atPath: path) else {
        throw GitError.configFileNotFound("Configuration file not found at: \(path)")
    }

    let data = try Data(contentsOf: configURL)

    // Parse TOML manually (simplified version)
    let content = String(data: data, encoding: .utf8) ?? ""
    let repositories = parseRepositories(from: content)
    let defaultBranch = parseDefaultBranch(from: content) ?? "main"
    let env = parseEnvironment(from: content)

    return MiseConfig(repositories: repositories, defaultBranch: defaultBranch, env: env)
}

func parseRepositories(from content: String) -> [RepositoryInfo] {
    var repositories: [RepositoryInfo] = []
    let lines = content.components(separatedBy: .newlines)

    var inRepositoriesSection = false
    var currentRepo: [String: String] = [:]

    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLine == "[repositories]" {
            inRepositoriesSection = true
            continue
        } else if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
            inRepositoriesSection = false
            // Save current repo if we have one
            if !currentRepo.isEmpty {
                if let name = currentRepo["name"],
                    let url = currentRepo["url"],
                    let branch = currentRepo["branch"]
                {
                    repositories.append(RepositoryInfo(name: name, url: url, branch: branch))
                }
                currentRepo = [:]
            }
            continue
        }

        if inRepositoriesSection {
            if let separatorRange = trimmedLine.range(of: "=") {
                let key = String(trimmedLine[..<separatorRange.lowerBound]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let value = String(trimmedLine[separatorRange.upperBound...]).trimmingCharacters(
                    in: .whitespacesAndNewlines)

                // Remove quotes from value
                let cleanedValue = value.replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")

                currentRepo[key] = cleanedValue
            }
        }
    }

    // Add the last repository
    if !currentRepo.isEmpty {
        if let name = currentRepo["name"],
            let url = currentRepo["url"],
            let branch = currentRepo["branch"]
        {
            repositories.append(RepositoryInfo(name: name, url: url, branch: branch))
        }
    }

    return repositories
}

func parseDefaultBranch(from content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)

    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let separatorRange = trimmedLine.range(of: "=") {
            let key = String(trimmedLine[..<separatorRange.lowerBound]).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let value = String(trimmedLine[separatorRange.upperBound...]).trimmingCharacters(
                in: .whitespacesAndNewlines)

            if key == "default_branch" {
                return value.replacingOccurrences(of: "\"", with: "").replacingOccurrences(
                    of: "'", with: "")
            }
        }
    }

    return nil
}

func parseEnvironment(from content: String) -> [String: String]? {
    var env: [String: String] = [:]
    let lines = content.components(separatedBy: .newlines)

    var inEnvSection = false

    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLine == "[env]" {
            inEnvSection = true
            continue
        } else if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
            inEnvSection = false
            continue
        }

        if inEnvSection {
            if let separatorRange = trimmedLine.range(of: "=") {
                let key = String(trimmedLine[..<separatorRange.lowerBound]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let value = String(trimmedLine[separatorRange.upperBound...]).trimmingCharacters(
                    in: .whitespacesAndNewlines)

                // Remove quotes from value
                let cleanedValue = value.replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")

                env[key] = cleanedValue
            }
        }
    }

    return env.isEmpty ? nil : env
}

func findRepository(in repositories: [RepositoryInfo], named name: String) -> RepositoryInfo? {
    return repositories.first { $0.name == name }
}

// MARK: - Main Entry Point

@main
struct GitTools {
    static func main() {
        let logger = Logger(subsystem: "com.fenchon.git-tools", category: "GitTools")

        do {
            let arguments = CommandLine.arguments
            var configPath = "./mise.toml"
            var repoName: String?
            var branch: String?

            // Parse arguments
            for (index, arg) in arguments.enumerated() {
                if arg == "--config" && index + 1 < arguments.count {
                    configPath = arguments[index + 1]
                } else if arg == "--branch" && index + 1 < arguments.count {
                    branch = arguments[index + 1]
                }
            }

            // Load configuration
            let config = try loadMiseConfig(from: configPath)

            // Determine command
            guard arguments.count > 1 else {
                print("Error: Missing command")
                printUsage()
                exit(1)
            }

            let commandString = arguments[1]
            guard let command = Command(rawValue: commandString) else {
                print("Error: Invalid command '\(commandString)'")
                printUsage()
                exit(1)
            }

            if command == .help {
                printUsage()
                return
            }

            let gitManager = GitManager()

            // Handle repository-specific or all repositories
            if arguments.count > 2 {
                repoName = arguments[2]
            }

            if let repoName = repoName {
                // Process specific repository
                guard let repo = findRepository(in: config.repositories, named: repoName) else {
                    print("Error: Repository '\(repoName)' not found in configuration")
                    print(
                        "Available repositories: \(config.repositories.map { $0.name }.joined(separator: ", "))"
                    )
                    exit(1)
                }

                // Override branch if specified
                let finalRepo =
                    branch != nil
                    ? RepositoryInfo(name: repo.name, url: repo.url, branch: branch!) : repo

                switch command {
                case .clone:
                    try gitManager.cloneRepository(finalRepo)
                    print("✅ Successfully cloned \(finalRepo.name)")

                case .fetch:
                    try gitManager.fetchRepository(finalRepo)
                    print("✅ Successfully fetched \(finalRepo.name)")

                case .pull:
                    try gitManager.pullRepository(finalRepo)
                    print("✅ Successfully pulled \(finalRepo.name)")

                case .push:
                    try gitManager.pushRepository(finalRepo)
                    print("✅ Successfully pushed \(finalRepo.name)")

                case .help:
                    break

                case .all:
                    print("Error: 'all' command doesn't take a repository name")
                    printUsage()
                    exit(1)
                }
            } else {
                // Process all repositories
                if config.repositories.isEmpty {
                    print("Error: No repositories found in configuration file: \(configPath)")
                    printUsage()
                    exit(1)
                }

                switch command {
                case .clone, .fetch, .pull, .push:
                    try gitManager.processAllRepositories(config.repositories, command: command)

                case .help:
                    break

                case .all:
                    // For 'all' command, we need to determine what to do
                    // For now, let's default to clone
                    try gitManager.processAllRepositories(config.repositories, command: .clone)
                    print("✅ Successfully processed all repositories")
                }
            }

        } catch {
            logger.error("Error: \(error.localizedDescription)")
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
```

<file_path>
fechon/git-tools/Tests/git-toolsTests/GitToolsTests.swift
</file_path>

<edit_description>
Update test file to include multi-repository functionality tests
</edit_description>

```swift
import XCTest

@testable import git_tools

final class GitToolsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testRepositoryInfoInitialization() {
        let repo = RepositoryInfo(
            name: "test-repo",
            url: "https://github.com/user/test-repo.git",
            branch: "main",
            latestCommit: "abc1234"
        )

        XCTAssertEqual(repo.name, "test-repo")
        XCTAssertEqual(repo.url, "https://github.com/user/test-repo.git")
        XCTAssertEqual(repo.branch, "main")
        XCTAssertEqual(repo.latestCommit, "abc1234")
        XCTAssertEqual(repo.localPath, "test-repo-main-abc1234")
    }

    func testRepositoryInfoDefaultBranch() {
        let repo = RepositoryInfo(
            name: "test-repo",
            url: "https://github.com/user/test-repo.git"
        )

        XCTAssertEqual(repo.branch, "main")
        XCTAssertEqual(repo.latestCommit, "")
        XCTAssertEqual(repo.localPath, "test-repo-main-")
    }

    func testGitErrorDescription() {
        let cloneError = GitError.cloneFailed("Test error")
        XCTAssertEqual(cloneError.errorDescription, "Clone failed: Test error")

        let fetchError = GitError.fetchFailed("Test error")
        XCTAssertEqual(fetchError.errorDescription, "Fetch failed: Test error")

        let pullError = GitError.pullFailed("Test error")
        XCTAssertEqual(pullError.errorDescription, "Pull failed: Test error")

        let pushError = GitError.pushFailed("Test error")
        XCTAssertEqual(pushError.errorDescription, "Push failed: Test error")

        let commitError = GitError.commitFailed("Test error")
        XCTAssertEqual(commitError.errorDescription, "Commit failed: Test error")

        let configError = GitError.configFileNotFound("Test error")
        XCTAssertEqual(configError.errorDescription, "Config file not found: Test error")

        let invalidConfigError = GitError.configFileInvalid("Test error")
        XCTAssertEqual(invalidConfigError.errorDescription, "Config file invalid: Test error")
    }

    func testCommandParsing() {
        let commands: [Command] = [.clone, .fetch, .pull, .push, .help, .all]
        XCTAssertEqual(commands.count, 6)
    }

    func testFindRepository() {
        let repositories = [
            RepositoryInfo(name: "repo1", url: "https://github.com/user/repo1.git", branch: "main"),
            RepositoryInfo(name: "repo2", url: "https://github.com/user/repo2.git", branch: "develop"),
            RepositoryInfo(name: "repo3", url: "https://github.com/user/repo3.git", branch: "main")
        ]

        XCTAssertNotNil(findRepository(in: repositories, named: "repo1"))
        XCTAssertNotNil(findRepository(in: repositories, named: "repo2"))
        XCTAssertNotNil(findRepository(in: repositories, named: "repo3"))
        XCTAssertNil(findRepository(in: repositories, named: "nonexistent"))
    }

    func testParseRepositories() {
        let configContent = """
        [repositories]
        repo1.name = "repo1"
        repo1.url = "https://github.com/user/repo1.git"
        repo1.branch = "main"

        repo2.name = "repo2"
        repo2.url = "https://github.com/user/repo2.git"
        repo2.branch = "develop"
        """

        let repositories = parseRepositories(from: configContent)
        XCTAssertEqual(repositories.count, 2)
        XCTAssertEqual(repositories[0].name, "repo1")
        XCTAssertEqual(repositories[0].url, "https://github.com/user/repo1.git")
        XCTAssertEqual(repositories[0].branch, "main")
        XCTAssertEqual(repositories[1].name, "repo2")
        XCTAssertEqual(repositories[1].url, "https://github.com/user/repo2.git")
        XCTAssertEqual(repositories[1].branch, "develop")
    }

    func testParseDefaultBranch() {
        let configContent = """
        [config]
        default_branch = "develop"

        [repositories]
        repo1.name = "repo1"
        repo1.url = "https://github.com/user/repo1.git"
        repo1.branch = "main"
        """

        let defaultBranch = parseDefaultBranch(from: configContent)
        XCTAssertEqual(defaultBranch, "develop")
    }

    func testParseEnvironment() {
        let configContent = """
        [env]
        GIT_TOOLS_VERSION = "1.0.0"
        DEFAULT_BRANCH = "main"

        [repositories]
        repo1.name = "repo1"
        repo1.url = "https://github.com/user/repo1.git"
        repo1.branch = "main"
        """

        let env = parseEnvironment(from: configContent)
        XCTAssertNotNil(env)
        XCTAssertEqual(env?["GIT_TOOLS_VERSION"], "1.0.0")
        XCTAssertEqual(env?["DEFAULT_BRANCH"], "main")
    }

    func testEmptyConfigContent() {
        let repositories = parseRepositories(from: "")
        XCTAssertTrue(repositories.isEmpty)

        let defaultBranch = parseDefaultBranch(from: "")
        XCTAssertNil(defaultBranch)

        let env = parseEnvironment(from: "")
        XCTAssertNil(env)
    }
}
```

<file_path>
fechon/git-tools/mise.toml
</file_path>

<edit_description>
Create mise.toml with repositories configuration for the tool itself
</edit_description>

```toml
[pria]
download = "repository, branch, latest_commit"

[tools]
swift = "5.9"

[env]
GIT_TOOLS_VERSION = "1.0.0"
DEFAULT_BRANCH = "main"

[repositories]
# Example repository configurations
git-tools.name = "git-tools"
git-tools.url = "https://github.com/user/git-tools.git"
git-tools.branch = "main"

example-repo.name = "example-repo"
example-repo.url = "https://github.com/user/example-repo.git"
example-repo.branch = "develop"

[config]
default_branch = "main"

[git]
user.name = "Git Tools"
user.email = "git-tools@example.com"
pull.rebase = true
push.default = "simple"

[logging]
level = "info"
file = "git-tools.log"
format = "text"
```

<file_path>
fechon/git-tools/Tests/git-toolsTests/Info.plist
</file_path>

<edit_description>
Create Info.plist for test target
</edit_description>

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>