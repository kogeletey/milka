import Foundation
import TOMLKit

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
        self.localPath = name
    }
}

struct MiseConfig {
    let repositories: [RepositoryInfo]
    let defaultBranch: String
    let env: [String: String]?
}

// MARK: - Configuration Loading

func loadMiseConfig(from path: String) throws -> MiseConfig {
    let configURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
        throw GitError.configFileNotFound("Configuration file not found at: \(path)")
    }
    let data = try Data(contentsOf: configURL)
    let content = String(data: data, encoding: .utf8) ?? ""
    // Simple line-by-line parsing for [[repo]] format
    var repositories: [RepositoryInfo] = []
    let lines = content.components(separatedBy: .newlines)
    var currentRepo: [String: String] = [:]
    var inRepoBlock = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.starts(with: "#") {
            continue  // Skip empty lines and comments
        }

        if trimmed == "[[repo]]" {
            // End previous repo if exists
            if !currentRepo.isEmpty && currentRepo["dir"] != nil && currentRepo["remote"] != nil {
                let dir = currentRepo["dir"] ?? "main"
                let remote = currentRepo["remote"] ?? ""
                let branch = currentRepo["branch"] ?? "main"
                let commit = currentRepo["commit"] ?? ""
                repositories.append(
                    RepositoryInfo(
                        name: dir, url: remote, branch: branch, latestCommit: commit)
                )
            }
            currentRepo = [:]
            inRepoBlock = true
            continue
        }

        if inRepoBlock {
            // Parse key = 'value'
            let components = trimmed.components(separatedBy: " = ")
            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: .whitespaces)
                let valuePart = components[1].trimmingCharacters(in: .whitespaces)
                // Extract value, handling single quotes
                if valuePart.hasPrefix("'") && valuePart.hasSuffix("'") {
                    let value = String(valuePart.dropFirst().dropLast())
                    currentRepo[key] = value
                }
            }
        }
    }

    // Handle the last repo block
    if !currentRepo.isEmpty && currentRepo["dir"] != nil && currentRepo["remote"] != nil {
        let dir = currentRepo["dir"] ?? "main"
        let remote = currentRepo["remote"] ?? ""
        let branch = currentRepo["branch"] ?? "main"
        let commit = currentRepo["commit"] ?? ""
        repositories.append(
            RepositoryInfo(
                name: dir, url: remote, branch: branch, latestCommit: commit)
        )
    }

    if repositories.isEmpty {
        printWarning(
            "No repositories found in config. Ensure .meta/reps.toml uses [[repo]] format with 'dir' and 'remote' keys."
        )
    }

    let defaultBranch = "main"
    let env: [String: String]? = nil

    return MiseConfig(repositories: repositories, defaultBranch: defaultBranch, env: env)
}

// MARK: - CLI Helper Functions

let ANSIColors = (
    reset: "\u{001B}[0m",
    info: "\u{001B}[34m",  // blue
    success: "\u{001B}[32m",  // green
    error: "\u{001B}[31m",  // red
    warning: "\u{001B}[33m"  // yellow
)

func printInfo(_ message: String) {
    print("\(ANSIColors.info)\(message)\(ANSIColors.reset)")
}

func printSuccess(_ message: String) {
    print("\(ANSIColors.success)\(message)\(ANSIColors.reset)")
}

func printError(_ message: String) {
    print("\(ANSIColors.error)\(message)\(ANSIColors.reset)")
}

func printWarning(_ message: String) {
    print("\(ANSIColors.warning)\(message)\(ANSIColors.reset)")
}

let spinnerChars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

@MainActor final class SpinnerState {
    var isActive: Bool = false
    var currentId: String = ""
    var currentLabel: String = ""

    func start(with label: String) -> String {
        let id = UUID().uuidString.prefix(8).description
        currentId = id
        currentLabel = label
        isActive = true
        return id
    }

    func stop(for id: String, success: Bool) {
        guard currentId == id else { return }
        isActive = false
        let (color, symbol) = success ? (ANSIColors.success, "✅") : (ANSIColors.error, "❌")
        print("\r\(color)\(symbol) \(currentLabel)\(ANSIColors.reset)", terminator: "")
        currentId = ""
        currentLabel = ""
    }

    func getState() -> (isActive: Bool, currentId: String, currentLabel: String) {
        (isActive, currentId, currentLabel)
    }

    func isActiveAndIdMatches(_ id: String) -> Bool {
        let state = getState()
        return state.isActive && state.currentId == id
    }
}

let spinnerState = SpinnerState()

@MainActor func startSpinner(label: String) -> String {
    let id = spinnerState.start(with: label)

    Task { @MainActor in
        var index = 0
        while spinnerState.isActiveAndIdMatches(id) {
            let state = spinnerState.getState()
            let char = spinnerChars[index % spinnerChars.count]
            print("\r\(char) \(state.currentLabel)", terminator: "")
            index += 1
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if spinnerState.getState().currentId == id {
            print("\r    ", terminator: "")
        }
    }

    return id
}

@MainActor func stopSpinner(_ id: String, success: Bool) {
    let state = spinnerState.getState()
    if state.currentId != id {
        printWarning("Spinner ID mismatch: \(id) vs \(state.currentId)")
        return
    }
    spinnerState.stop(for: id, success: success)
}

// MARK: - Helper Functions

func printUsage() {
    print(
        """
        Mise Milka - A command-line tool for managing multiple git repositories

        Usage: mise-milka <command> [repo-name] [options]

        Commands:
          clone [repo-name]    Clone a repository or all repositories (if no repo-name provided)
          fetch [repo-name]    Fetch updates for a repository or all repositories (if no repo-name provided)
          pull [repo-name]     Pull latest changes for a repository or all repositories (if no repo-name provided)
          push [repo-name]     Push changes for a repository or all repositories (if no repo-name provided)
          help                 Show this help message

        Options:
          --config <path>      Path to reps.toml configuration file (default: ./.meta/reps.toml)
          --branch <branch>    Specify branch (default: from config or main)

        Examples:
          mise-milka clone                    Clone all repositories from reps.toml
          mise-milka clone my-repo            Clone specific repository
          mise-milka fetch                    Fetch updates for all repositories
          mise-milka fetch my-repo            Fetch updates for specific repository
          mise-milka pull                     Pull latest changes for all repositories
          mise-milka pull my-repo             Pull latest changes for specific repository
          mise-milka push                    Push changes for all repositories
          mise-milka push my-repo             Push changes for specific repository
          mise-milka --config /path/to/reps.toml clone
          mise-milka --config /path/to/reps.toml --branch feature-branch clone my-repo
        """
    )
}

func findRepository(in repositories: [RepositoryInfo], named name: String) -> RepositoryInfo? {
    return repositories.first { $0.name == name }
}

// MARK: - Command Line Interface

enum Command: String {
    case clone = "clone"
    case fetch = "fetch"
    case pull = "pull"
    case push = "push"
    case help = "help"
}

// MARK: - Main Entry Point

let args = CommandLine.arguments
var configPath = ".meta/reps.toml"
var branchOverride: String? = nil
var nonOptionArgs: [String] = []

var i = 1
while i < args.count {
    let arg = args[i]
    if arg == "--config" && i + 1 < args.count {
        configPath = args[i + 1]
        i += 2
        continue
    } else if arg == "--branch" && i + 1 < args.count {
        branchOverride = args[i + 1]
        i += 2
        continue
    } else if arg.hasPrefix("--") {
        i += 1
        continue
    } else {
        nonOptionArgs.append(arg)
        i += 1
    }
}

guard !nonOptionArgs.isEmpty else {
    printUsage()
    exit(1)
}

let commandString = nonOptionArgs[0]
guard let command = Command(rawValue: commandString) else {
    printError("Error: Invalid command '\(commandString)'")
    printUsage()
    exit(1)
}

if command == .help {
    printUsage()
    exit(0)
}

let repoName = nonOptionArgs.count > 1 ? nonOptionArgs[1] : nil

// Load configuration
let config: MiseConfig
do {
    config = try loadMiseConfig(from: configPath)
    printInfo("Loaded \(config.repositories.count) repositories")
} catch {
    printError("❌ Error: \(error.localizedDescription)")
    exit(1)
}

// If no repos loaded, exit early
guard !config.repositories.isEmpty else {
    printError(
        "No repositories available to process. Check the warning above and your config file."
    )
    exit(1)
}

// Override branch if specified
var repositories = config.repositories
if let branch = branchOverride {
    repositories = repositories.map {
        RepositoryInfo(
            name: $0.name, url: $0.url, branch: branch, latestCommit: $0.latestCommit)
    }
}

let gitManager = GitManager()

do {
    if let name = repoName {
        guard let repo = findRepository(in: repositories, named: name) else {
            printError("❌ Error: Repository '\(name)' not found in configuration")
            exit(1)
        }
        try gitManager.processAllRepositories([repo], command: command)
    } else {
        try gitManager.processAllRepositories(repositories, command: command)
    }
} catch {
    printError("❌ Error: \(error.localizedDescription)")
    exit(1)
}
