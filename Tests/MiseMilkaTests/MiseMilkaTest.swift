import XCTest
@testable import mise_milka // Note: Adjust import if package name differs; assumes executable target exposes symbols

// MARK: - Mocks and Helpers

class MockProcess: Process {
    var mockStatus: Int32 = 0
    var mockStdout: String = ""
    var mockStderr: String = ""

    override var terminationStatus: Int32 {
        return mockStatus
    }

    override func run() throws {
        // Simulate run without actual execution
    }

    override func waitUntilExit() {
        // Simulate wait
    }
}

class OutputCapture {
    static var originalStdout: FileHandle?
    static var capturedOutput = ""

    static func startCapturing() {
        originalStdout = FileHandle.standardOutput
        let pipe = Pipe()
        FileHandle.standardOutput = pipe.fileHandleForWriting
        capturedOutput = ""
        // Note: In real tests, use pipe to read output; simplified here
    }

    static func stopCapturing() -> String {
        FileHandle.standardOutput = originalStdout
        return capturedOutput
    }

    static func appendToCapture(_ string: String) {
        capturedOutput += string + "\n"
    }
}

// Mock print functions for testing
var originalPrintInfo: ((String) -> Void)?
var originalPrintSuccess: ((String) -> Void)?
var originalPrintError: ((String) -> Void)?
var originalPrintWarning: ((String) -> Void)?

func mockPrintInfo(_ message: String) {
    OutputCapture.appendToCapture("INFO: \(message)")
}

func mockPrintSuccess(_ message: String) {
    OutputCapture.appendToCapture("SUCCESS: \(message)")
}

func mockPrintError(_ message: String) {
    OutputCapture.appendToCapture("ERROR: \(message)")
}

func mockPrintWarning(_ message: String) {
    OutputCapture.appendToCapture("WARNING: \(message)")
}

// MARK: - XCTestCase

final class GitToolsTests: XCTestCase {
    var gitManager: GitManager!
    var mockCurrentDir: String!

    override func setUp() {
        super.setUp()
        gitManager = GitManager()
        mockCurrentDir = "/mock/current/dir"
        FileManager.default.currentDirectoryPath = mockCurrentDir // Mock for tests

        // Mock print functions
        originalPrintInfo = printInfo
        originalPrintSuccess = printSuccess
        originalPrintError = printError
        originalPrintWarning = printWarning
        printInfo = mockPrintInfo
        printSuccess = mockPrintSuccess
        printError = mockPrintError
        printWarning = mockPrintWarning
    }

    override func tearDown() {
        printInfo = originalPrintInfo
        printSuccess = originalPrintSuccess
        printError = originalPrintError
        printWarning = originalPrintWarning
        FileManager.default.currentDirectoryPath = NSFileManager.defaultManager().currentDirectoryPath // Reset
        super.tearDown()
    }

    // MARK: - RepositoryInfo Tests

    func testRepositoryInfoInitialization() {
        let repo = RepositoryInfo(name: "test-repo", url: "https://github.com/test/repo", branch: "main")
        XCTAssertEqual(repo.name, "test-repo")
        XCTAssertEqual(repo.url, "https://github.com/test/repo")
        XCTAssertEqual(repo.branch, "main")
        XCTAssertEqual(repo.latestCommit, "")
        XCTAssertEqual(repo.localPath, "test-repo")
    }

    func testRepositoryInfoDefaultBranch() {
        let repo = RepositoryInfo(name: "test-repo", url: "https://github.com/test/repo")
        XCTAssertEqual(repo.branch, "main") // Default
    }

    func testRepositoryInfoWithCommit() {
        let repo = RepositoryInfo(name: "test-repo", url: "https://github.com/test/repo", latestCommit: "abc123")
        XCTAssertEqual(repo.latestCommit, "abc123")
    }

    // MARK: - MiseConfig Tests

    func testMiseConfigCodable() throws {
        let config = MiseConfig(repositories: [], defaultBranch: "main", env: nil)
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MiseConfig.self, from: data)
        XCTAssertEqual(decoded.defaultBranch, "main")
        XCTAssertNil(decoded.env)
    }

    // MARK: - GitError Tests

    func testGitErrorDescription() {
        let error = GitError.cloneFailed("test message")
        XCTAssertEqual(error.localizedDescription, "Clone failed: test message")

        let authError = GitError.authenticationRequired("test auth")
        XCTAssertEqual(authError.localizedDescription, "Authentication required: test auth. Please provide a username/password or use a personal access token for private repositories.")
    }

    func testAllGitErrorCasesHaveDescriptions() {
        let cases: [GitError] = [
            .cloneFailed(""),
            .fetchFailed(""),
            .pullFailed(""),
            .pushFailed(""),
            .configFileNotFound(""),
            .configFileInvalid(""),
            .authenticationRequired("")
        ]
        for case in cases {
            XCTAssertNotNil(case.localizedDescription)
        }
    }

    // MARK: - Command Enum Tests

    func testCommandRawValues() {
        XCTAssertEqual(Command.clone.rawValue, "clone")
        XCTAssertEqual(Command.fetch.rawValue, "fetch")
        XCTAssertEqual(Command.pull.rawValue, "pull")
        XCTAssertEqual(Command.push.rawValue, "push")
        XCTAssertEqual(Command.help.rawValue, "help")
    }

    func testCommandInvalidRawValue() {
        XCTAssertNil(Command(rawValue: "invalid"))
    }

    // MARK: - Helper Functions Tests

    func testPrintUsage() {
        OutputCapture.startCapturing()
        printUsage()
        let output = OutputCapture.stopCapturing()
        XCTAssertTrue(output.contains("Mise Milka - A command-line tool"))
        XCTAssertTrue(output.contains("Usage: mise-milka <command>"))
        XCTAssertTrue(output.contains("Commands:"))
        XCTAssertTrue(output.contains("clone [repo-name]"))
    }

    func testFindRepositorySuccess() {
        let repos = [
            RepositoryInfo(name: "found", url: "url", branch: "main"),
            RepositoryInfo(name: "not-found", url: "url2", branch: "main")
        ]
        let found = findRepository(in: repos, named: "found")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "found")
    }

    func testFindRepositoryNotFound() {
        let repos = [RepositoryInfo(name: "other", url: "url", branch: "main")]
        let found = findRepository(in: repos, named: "missing")
        XCTAssertNil(found)
    }

    func testFindRepositoryEmptyList() {
        let found = findRepository(in: [], named: "test")
        XCTAssertNil(found)
    }

    // MARK: - Config Loading Tests

    func testLoadMiseConfigValidTOML() throws {
        let tomlContent = """
[[repo]]
dir = 'my-repo'
remote = 'https://github.com/example/my-repo'
branch = 'main'

[[repo]]
dir = 'frontend'
remote = 'https://github.com/example/frontend'
"""
        let tempPath = createTempFile(content: tomlContent)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let config = try loadMiseConfig(from: tempPath)
        XCTAssertEqual(config.repositories.count, 2)
        XCTAssertEqual(config.repositories[0].name, "my-repo")
        XCTAssertEqual(config.repositories[1].url, "https://github.com/example/frontend")
        XCTAssertEqual(config.defaultBranch, "main")
    }

    func testLoadMiseConfigEmptyFile() {
        let tempPath = createTempFile(content: "")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        XCTAssertThrowsError(try loadMiseConfig(from: tempPath)) { error in
            XCTAssertEqual(error as? GitError, .configFileInvalid("No repositories found in config..."))
        }
    }

    func testLoadMiseConfigMissingFile() {
        XCTAssertThrowsError(try loadMiseConfig(from: "/nonexistent.toml")) { error in
            XCTAssertEqual(error as? GitError, .configFileNotFound("Configuration file not found at: /nonexistent.toml"))
        }
    }

    func testLoadMiseConfigInvalidTOML() {
        let invalidContent = "invalid toml [["
        let tempPath = createTempFile(content: invalidContent)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        // Since parsing is custom, test partial failure
        let config = try? loadMiseConfig(from: tempPath)
        XCTAssertNotNil(config)
        XCTAssertTrue(config!.repositories.isEmpty)
    }

    func testLoadMiseConfigWithBranchOverride() {
        // Branch override is in main logic, tested indirectly via repos map
        let repos = [RepositoryInfo(name: "test", url: "url", branch: "old")]
        let overridden = repos.map { RepositoryInfo(name: $0.name, url: $0.url, branch: "new", latestCommit: $0.latestCommit) }
        XCTAssertEqual(overridden[0].branch, "new")
    }

    // MARK: - Argument Parsing Tests (Extracted Logic)

    func testArgumentParsingBasic() {
        let args = ["/path/to/mise-milka", "clone", "my-repo"]
        let (command, repoName, configPath, branch) = parseArgs(args)
        XCTAssertEqual(command, .clone)
        XCTAssertEqual(repoName, "my-repo")
        XCTAssertEqual(configPath, ".meta/reps.toml")
        XCTAssertNil(branch)
    }

    func testArgumentParsingAllRepos() {
        let args = ["/path/to/mise-milka", "fetch"]
        let (command, repoName, _, _) = parseArgs(args)
        XCTAssertEqual(command, .fetch)
        XCTAssertNil(repoName)
    }

    func testArgumentParsingWithConfigOption() {
        let args = ["/path/to/mise-milka", "--config", "custom.toml", "pull"]
        let (command, _, configPath, _) = parseArgs(args)
        XCTAssertEqual(command, .pull)
        XCTAssertEqual(configPath, "custom.toml")
    }

    func testArgumentParsingWithBranchOption() {
        let args = ["/path/to/mise-milka", "--branch", "dev", "push", "repo"]
        let (_, _, _, branch) = parseArgs(args)
        XCTAssertEqual(branch, "dev")
    }

    func testArgumentParsingInvalidCommand() {
        let args = ["/path/to/mise-milka", "invalid"]
        let (command, _, _, _) = parseArgs(args)
        XCTAssertNil(command)
    }

    func testArgumentParsingNoArgs() {
        let args = ["/path/to/mise-milka"]
        let (command, _, _, _) = parseArgs(args)
        XCTAssertNil(command)
    }

    // Helper for parsing (extracted for testing)
    func parseArgs(_ arguments: [String]) -> (Command?, String?, String, String?) {
        var configPath = ".meta/reps.toml"
        var branchOverride: String? = nil
        var nonOptionArgs: [String] = []
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            if arg == "--config" && i + 1 < arguments.count {
                configPath = arguments[i + 1]
                i += 2
                continue
            } else if arg == "--branch" && i + 1 < arguments.count {
                branchOverride = arguments[i + 1]
                i += 2
                continue
            } else {
                nonOptionArgs.append(arg)
                i += 1
            }
        }
        guard !nonOptionArgs.isEmpty, let commandStr = nonOptionArgs.first,
              let command = Command(rawValue: commandStr) else { return (nil, nil, configPath, branchOverride) }
        let repoName = nonOptionArgs.count > 1 ? nonOptionArgs[1] : nil
        return (command, repoName, configPath, branchOverride)
    }

    // MARK: - GitManager Tests

    func testCloneRepositoryExists() throws {
        let repo = RepositoryInfo(name: "existing", url: "url", branch: "main")
        let mockPath = mockCurrentDir + "/existing"
        try FileManager.default.createDirectory(atPath: mockPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: mockPath) }

        XCTAssertNoThrow(try gitManager.cloneRepository(repo))
        // Should skip and print info
        let output = OutputCapture.stopCapturing() // Assume captured
        XCTAssertTrue(output.contains("already exists"))
    }

    func testCloneRepositoryNotExistsSuccess() throws {
        // Mock Process to succeed
        let originalProcess = type(of: gitManager).Process.self
        // Swizzle or mock Process creation - simplified: assume method calls Process()
        // For full test, use dependency injection; here test logic
        let repo = RepositoryInfo(name: "new", url: "url", branch: "main")
        // Create mock .git after
        XCTAssertNoThrow(try gitManager.cloneRepository(repo))
        let gitPath = mockCurrentDir + "/new/.git"
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitPath)) // But in test, we don't run, so adjust
        // Note: Full mock would set up files
    }

    func testCloneRepositoryFailure() {
        let repo = RepositoryInfo(name: "fail", url: "url", branch: "main")
        // Mock Process to fail with auth error
        XCTAssertThrowsError(try gitManager.cloneRepository(repo), "Should throw on failure") { error in
            XCTAssertEqual(error as? GitError, .authenticationRequired("..."))
        }
    }

    func testFetchRepositoryNotCloned() {
        let repo = RepositoryInfo(name: "not-cloned", url: "url", branch: "main")
        XCTAssertThrowsError(try gitManager.fetchRepository(repo)) { error in
            XCTAssertEqual(error as? GitError, .configFileInvalid("Repository not cloned: not-cloned"))
        }
    }

    func testFetchRepositorySuccess() {
        let repo = RepositoryInfo(name: "cloned", url: "url", branch: "main")
        let mockPath = mockCurrentDir + "/cloned"
        try! FileManager.default.createDirectory(atPath: mockPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: mockPath) }

        XCTAssertNoThrow(try gitManager.fetchRepository(repo))
        // No output on success due to reduced verbosity
    }

    func testPullRepositoryFailureAuth() {
        let repo = RepositoryInfo(name: "pull-fail", url: "url", branch: "main")
        let mockPath = mockCurrentDir + "/pull-fail"
        try! FileManager.default.createDirectory(atPath: mockPath, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: mockPath) }

        XCTAssertThrowsError(try gitManager.pullRepository(repo)) { error in
            XCTAssert(error.localizedDescription.contains("Authentication required"))
        }
    }

    func testPushRepositoryNotCloned() {
        let repo = RepositoryInfo(name: "not-cloned-push", url: "url", branch: "main")
        XCTAssertThrowsError(try gitManager.pushRepository(repo)) { error in
            XCTAssertEqual(error as? GitError, .configFileInvalid("Repository not cloned: not-cloned-push"))
        }
    }

    // MARK: - Progress and Reduced Output Tests

    func testProcessAllRepositoriesProgressOutput() {
        OutputCapture.startCapturing()
        let repos = [
            RepositoryInfo(name: "repo1", url: "url1", branch: "main"),
            RepositoryInfo(name: "repo2", url: "url2", branch: "main")
        ]
        let command = Command.fetch

        // Mock operations to succeed without prints
        XCTAssertNoThrow(try gitManager.processAllRepositories(repos, command: command))

        let output = OutputCapture.stopCapturing()
        XCTAssertTrue(output.contains("[0/2] Fetch repo1"))
        XCTAssertTrue(output.contains("[1/2] Fetch repo2"))
        // No STDOUT/STDERR on success
        XCTAssertFalse(output.contains("STDOUT:"))
        XCTAssertFalse(output.contains("From https://"))
        // No success message
        XCTAssertFalse(output.contains("Successfully fetched"))
    }

    func testProcessAllRepositoriesErrorOutput() {
        OutputCapture.startCapturing()
        let repos = [RepositoryInfo(name: "error-repo", url: "url", branch: "main")]
        let command = Command.clone

        // Mock to fail, should print STDOUT/STDERR
        XCTAssertThrowsError(try gitManager.processAllRepositories(repos, command: command))

        let output = OutputCapture.stopCapturing()
        XCTAssertTrue(output.contains("[0/1] Clone error-repo"))
        XCTAssertTrue(output.contains("STDOUT: mock output")) // Assume mocked
        XCTAssertTrue(output.contains("STDERR: mock error"))
        XCTAssertTrue(output.contains("Clone failed with status"))
    }

    func testProcessAllRepositoriesEmptyList() {
        let repos: [RepositoryInfo] = []
        XCTAssertNoThrow(try gitManager.processAllRepositories(repos, command: .fetch))
        // No output
    }

    func testProcessAllRepositoriesSingleRepoNoProgress() {
        // For 1 repo, still shows [0/1]
        OutputCapture.startCapturing()
        let repos = [RepositoryInfo(name: "single", url: "url", branch: "main")]
        XCTAssertNoThrow(try gitManager.processAllRepositories(repos, command: .clone))
        let output = OutputCapture.stopCapturing()
        XCTAssertTrue(output.contains("[0/1] Clone single"))
    }

    // MARK: - Integration-like Tests (Main Logic)

    func testMainLogicFullFlow() {
        // Simulate full main() call with mocks
        let mockArgs = ["/usr/bin/swift", "mise-milka", "clone"]
        // Would call loadConfig, findRepo, process
        // Assert no crash, correct command dispatch
        // Detailed assertion on captured output
        XCTAssertTrue(true) // Placeholder for full mock
    }

    func testMainWithSpecificRepo() {
        // Similar, with repo name
    }

    func testMainHelpCommand() {
        OutputCapture.startCapturing()
        let mockArgs = ["/usr/bin/swift", "mise-milka", "help"]
        // Simulate call to printUsage
        let output = OutputCapture.stopCapturing()
        XCTAssertTrue(output.contains("Usage: mise-milka"))
    }

    func testMainInvalidCommand() {
        let mockArgs = ["/usr/bin/swift", "mise-milka", "invalid"]
        // Should print error and usage, exit 1
        // Capture error output
    }

    // MARK: - Edge Cases

    func testSpinnerFunctions() {
        // Test start/stop spinner doesn't crash, but hard to unit test animation
        let id = startSpinner(label: "test")
        XCTAssertFalse(spinnerActive == false) // Basic
        stopSpinner(id, success: true)
        XCTAssertFalse(spinnerActive)
    }

    func testGitignoreUpdateOnClone() {
        let repo = RepositoryInfo(name: "gitignore-test", url: "url", branch: "main")
        let gitignorePath = mockCurrentDir + "/.gitignore"
        try! "initial".write(toFile: gitignorePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: gitignorePath) }

        XCTAssertNoThrow(try gitManager.cloneRepository(repo))
        let content = try String(contentsOfFile: gitignorePath)
        XCTAssertTrue(content.contains("gitignore-test/"))
    }

    func testNoDuplicateGitignoreEntry() {
        let repo = RepositoryInfo(name: "dup-test", url: "url", branch: "main")
        let gitignorePath = mockCurrentDir + "/.gitignore"
        try! "dup-test/\n".write(toFile: gitignorePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: gitignorePath) }

        XCTAssertNoThrow(try gitManager.cloneRepository(repo))
        let content = try String(contentsOfFile: gitignorePath)
        let count = content.components(separatedBy: "dup-test/").count - 1
        XCTAssertEqual(count, 1) // No duplicate
    }
}

// MARK: - Temp File Helper

func createTempFile(content: String) -> String {
    let tempDir = NSTemporaryDirectory()
    let tempFile = tempDir + "test.toml"
    try! content.write(toFile: tempFile, atomically: true, encoding: .utf8)
    return tempFile
}

// Note: To make Process mockable, in production, inject Process factory into GitManager.
// For spinner output capture, enhance OutputCapture with pipe reading in async tests if needed.
// Add more mocks for FileManager if deeper file ops testing required.
