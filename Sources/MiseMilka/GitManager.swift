import Foundation

// MARK: - Errors

enum GitError: Error, LocalizedError {
    case cloneFailed(String)
    case fetchFailed(String)
    case pullFailed(String)
    case pushFailed(String)
    case configFileNotFound(String)
    case configFileInvalid(String)
    case authenticationRequired(String)

    var errorDescription: String? {
        switch self {
        case .cloneFailed(let message): return "Clone failed: \(message)"
        case .fetchFailed(let message): return "Fetch failed: \(message)"
        case .pullFailed(let message): return "Pull failed: \(message)"
        case .pushFailed(let message): return "Push failed: \(message)"
        case .configFileNotFound(let message): return "Config file not found: \(message)"
        case .configFileInvalid(let message): return "Config file invalid: \(message)"
        case .authenticationRequired(let message):
            return
                "Authentication required: \(message). Please provide a username/password or use a personal access token for private repositories."
        }
    }
}

// MARK: - Git Operations Manager

class GitManager {
    // Note: No console dependency, using global helpers

    @MainActor func cloneRepository(_ repo: RepositoryInfo) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let localPath = repo.name
        let absoluteLocalPath = URL(fileURLWithPath: currentDir).appendingPathComponent(
            localPath
        ).path
        if FileManager.default.fileExists(atPath: absoluteLocalPath) {
            printInfo(
                "Repository \(repo.name) already exists at \(absoluteLocalPath), skipping clone.")
            return
        }

        let spinnerId = startSpinner(label: "Cloning \(repo.name)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = URL(fileURLWithPath: currentDir)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.arguments = ["clone", "--branch", repo.branch, repo.url, localPath]
        try process.run()
        process.waitUntilExit()
        let status = process.terminationStatus
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutOutput = String(data: stdoutData, encoding: .utf8) ?? "No stdout"
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? "No stderr"
        stopSpinner(spinnerId, success: status == 0)
        guard status == 0 else {
            if !stdoutOutput.isEmpty {
                printInfo("STDOUT: \(stdoutOutput.trimmingCharacters(in: .newlines))")
            }
            if !stderrOutput.isEmpty {
                printError("STDERR: \(stderrOutput.trimmingCharacters(in: .newlines))")
            }
            printError(
                "Clone failed with status \(status). Check above output for details (e.g., network issues, invalid URL, or permissions)."
            )
            let authKeywords = [
                "Authentication failed", "Invalid username", "Permission denied",
                "remote: Support for password authentication was removed",
                "fatal: could not read Username",
            ]
            if authKeywords.contains(where: { stderrOutput.contains($0) }) {
                throw GitError.authenticationRequired(
                    "Git operation requires authentication for \(repo.url)")
            }
            throw GitError.cloneFailed("Failed to clone repository \(repo.url) (status: \(status))")
        }

        // Verify clone by checking .git directory
        let gitPath = "\(absoluteLocalPath)/.git"
        guard FileManager.default.fileExists(atPath: gitPath) else {
            printWarning(
                "Warning: .git directory not found in \(absoluteLocalPath). Clone may have failed.")
            return
        }

        // Add cloned directory to .gitignore
        let gitignorePath = "\(currentDir)/.gitignore"
        let repoDir = "\(localPath)/"
        var gitignoreContent = ""
        var shouldAdd = true

        if FileManager.default.fileExists(atPath: gitignorePath) {
            do {
                gitignoreContent = try String(contentsOfFile: gitignorePath, encoding: .utf8)
                if gitignoreContent.contains(repoDir) {
                    shouldAdd = false
                }
            } catch {
                printWarning("Could not read .gitignore: \(error.localizedDescription)")
            }
        }

        if shouldAdd {
            if gitignoreContent.isEmpty {
                gitignoreContent = repoDir
            } else {
                gitignoreContent += "\n\(repoDir)"
            }
            do {
                try gitignoreContent.write(toFile: gitignorePath, atomically: true, encoding: .utf8)
                printInfo("Added '\(repoDir)' to .gitignore")
            } catch {
                printWarning("Could not update .gitignore: \(error.localizedDescription)")
            }
        }
    }

    @MainActor func fetchRepository(_ repo: RepositoryInfo) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let localPath = repo.name
        let absoluteLocalPath = URL(fileURLWithPath: currentDir).appendingPathComponent(
            localPath
        ).path
        guard FileManager.default.fileExists(atPath: absoluteLocalPath) else {
            throw GitError.configFileInvalid("Repository not cloned: \(repo.name)")
        }

        let spinnerId = startSpinner(label: "Fetching \(repo.name)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.arguments = ["fetch", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: absoluteLocalPath, isDirectory: true)
        try process.run()
        process.waitUntilExit()
        let status = process.terminationStatus
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutOutput = String(data: stdoutData, encoding: .utf8) ?? "No stdout"
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? "No stderr"
        stopSpinner(spinnerId, success: status == 0)
        guard status == 0 else {
            if !stdoutOutput.isEmpty {
                printInfo("STDOUT: \(stdoutOutput.trimmingCharacters(in: .newlines))")
            }
            if !stderrOutput.isEmpty {
                printError("STDERR: \(stderrOutput.trimmingCharacters(in: .newlines))")
            }
            let authKeywords = [
                "Authentication failed", "Invalid username", "Permission denied",
                "remote: Support for password authentication was removed",
                "fatal: could not read Username",
            ]
            if authKeywords.contains(where: { stderrOutput.contains($0) }) {
                throw GitError.authenticationRequired(
                    "Git operation requires authentication for \(repo.name)")
            }
            throw GitError.fetchFailed("Failed to fetch repository \(repo.name)")
        }
    }

    @MainActor func pullRepository(_ repo: RepositoryInfo) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let localPath = repo.name
        let absoluteLocalPath = URL(fileURLWithPath: currentDir).appendingPathComponent(
            localPath
        ).path
        guard FileManager.default.fileExists(atPath: absoluteLocalPath) else {
            throw GitError.configFileInvalid("Repository not cloned: \(repo.name)")
        }

        let spinnerId = startSpinner(label: "Pulling \(repo.name)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.arguments = ["pull", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: absoluteLocalPath, isDirectory: true)
        try process.run()
        process.waitUntilExit()
        let status = process.terminationStatus
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutOutput = String(data: stdoutData, encoding: .utf8) ?? "No stdout"
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? "No stderr"
        stopSpinner(spinnerId, success: status == 0)
        guard status == 0 else {
            if !stdoutOutput.isEmpty {
                printInfo("STDOUT: \(stdoutOutput.trimmingCharacters(in: .newlines))")
            }
            if !stderrOutput.isEmpty {
                printError("STDERR: \(stderrOutput.trimmingCharacters(in: .newlines))")
            }
            let authKeywords = [
                "Authentication failed", "Invalid username", "Permission denied",
                "remote: Support for password authentication was removed",
                "fatal: could not read Username",
            ]
            if authKeywords.contains(where: { stderrOutput.contains($0) }) {
                throw GitError.authenticationRequired(
                    "Git operation requires authentication for \(repo.name)")
            }
            throw GitError.pullFailed("Failed to pull repository \(repo.name)")
        }
    }

    @MainActor func pushRepository(_ repo: RepositoryInfo) throws {
        let currentDir = FileManager.default.currentDirectoryPath
        let localPath = repo.name
        let absoluteLocalPath = URL(fileURLWithPath: currentDir).appendingPathComponent(
            localPath
        ).path
        guard FileManager.default.fileExists(atPath: absoluteLocalPath) else {
            throw GitError.configFileInvalid("Repository not cloned: \(repo.name)")
        }

        let spinnerId = startSpinner(label: "Pushing \(repo.name)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.arguments = ["push", "origin", repo.branch]
        process.currentDirectoryURL = URL(fileURLWithPath: absoluteLocalPath, isDirectory: true)
        try process.run()
        process.waitUntilExit()
        let status = process.terminationStatus
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutOutput = String(data: stdoutData, encoding: .utf8) ?? "No stdout"
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? "No stderr"
        stopSpinner(spinnerId, success: status == 0)
        guard status == 0 else {
            if !stdoutOutput.isEmpty {
                printInfo("STDOUT: \(stdoutOutput.trimmingCharacters(in: .newlines))")
            }
            if !stderrOutput.isEmpty {
                printError("STDERR: \(stderrOutput.trimmingCharacters(in: .newlines))")
            }
            let authKeywords = [
                "Authentication failed", "Invalid username", "Permission denied",
                "remote: Support for password authentication was removed",
                "fatal: could not read Username",
            ]
            if authKeywords.contains(where: { stderrOutput.contains($0) }) {
                throw GitError.authenticationRequired(
                    "Git operation requires authentication for \(repo.name)")
            }
            throw GitError.pushFailed("Failed to push repository \(repo.name)")
        }
    }

    @MainActor func processAllRepositories(_ repositories: [RepositoryInfo], command: Command)
        throws
    {
        for (index, repo) in repositories.enumerated() {
            let action = command.rawValue.capitalized
            printInfo("[\(index)/\(repositories.count)] \(action) \(repo.name)")
            switch command {
            case .clone:
                try cloneRepository(repo)
            case .fetch:
                try fetchRepository(repo)
            case .pull:
                try pullRepository(repo)
            case .push:
                try pushRepository(repo)
            case .help:
                break
            }
        }
    }
}
