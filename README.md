# Milka

A command-line tool for managing multiple git repositories simultaneously. Milka allows you to clone, fetch, pull, and push changes across multiple repositories with a single command, making it easy to manage projects with multiple related repositories.

## TL;DR

Quick start with Milka:

1. **Install**: Download from [Releases](https://github.com/kogeletey/milka/releases) or build from source
2. **Configure**: Create `.meta/reps.toml` with your repositories
3. **Use**: Run commands like `milka clone`, `milka pull`, `milka push` to manage all repos at once

Example config:
```toml
[[repo]]
dir = 'my-project'
remote = 'https://github.com/username/my-project.git'
branch = 'main'

[[repo]]
dir = 'my-submodule'
remote = 'https://github.com/username/submodule.git'
branch = 'main'
source = 'git+subtree'  # For subtree operations (new feature!)
```

**New Feature: Subtree Support** - Use the `--subtree` flag to work only with repositories that have `source = "git+subtree"` in your configuration!

## 🚀 Version 2025.11.6 Highlights (Latest Release)

- **Enhanced error handling**: Improved error messages and handling for repository operations
- **Performance improvements**: Faster repository scanning and operations with large numbers of repositories
- **Configuration validation**: Automatic validation of `.meta/reps.toml` configuration file format
- **Improved logging**: More detailed logging and progress information during operations

## 🚀 Version 2025.11.5 Highlights

- **New `create` command**: Replace `init` with `milka create <repo-name>` to create new git repositories
- **Subtree repository creation**: Use `milka create <dir> --subtree` to set up subtree repositories in existing directories
- **Git initialization for non-git directories**: Enhanced scan functionality automatically initializes git when using `--subtree` flag


## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Commands](#commands)
- [Usage Examples](#usage-examples)
- [Author](#author)
- [License](#license)

## Features

- **Clone multiple repositories** at once using a configuration file
- **Fetch updates** from multiple repositories simultaneously
- **Pull latest changes** from all configured repositories
- **Push changes** to multiple repositories at once
- **Subtree support** - Use git subtree operations with `--subtree` flag (new!)
- **Scan** current directory for existing git repositories and add them to configuration
- **Colored output** for better readability
- **Spinner indicators** for ongoing operations
- **Authentication support** for private repositories using personal access tokens

## Installation

### From Source

1. Ensure you have [Crystal](https://crystal-lang.org/) installed (version >= 1.0.0)
2. Clone this repository
3. Build the project:
   ```bash
   shards build
   ```
4. The executable will be available as `bin/milka`

### Pre-built Binaries

Pre-built static binaries are available for download on the [Releases](https://github.com/kogeletey/milka/releases) page. These are statically linked and can run on most systems without additional dependencies.

1. Download the appropriate binary for your platform
2. Extract the archive
3. Make the binary executable (on Unix-like systems): `chmod +x milka`
4. Optionally, move the binary to a directory in your PATH

## Building with Container static build

You can also build Milka using the provided container configuration. See `.meta/packaging/static-builds/Containerfile` for the container build setup.

### Docker
```bash
# Build the container
docker build -f .meta/packaging/static-builds/Containerfile -t milka .

# Run commands in the container
docker run --rm -v $(pwd):/workspace -w /workspace milka clone
docker run --rm -v $(pwd):/workspace -w /workspace milka pull

# Copy the static binary from the built container
docker create --name milka-container milka
docker cp milka-container:/usr/local/bin/milka ./milka
docker rm -v milka-container
```

Container builds provide a reproducible build environment and make it easy to run Milka in containerized environments.

## Quick Start

1. Create a `.meta/reps.toml` configuration file in your project root with the repositories you want to manage:

    ```toml
    [[repo]]
    dir = 'my-project'
    remote = 'https://github.com/username/my-project.git'
    branch = 'main'

    [[repo]]
    dir = 'my-other-project'
    remote = 'https://github.com/username/my-other-project.git'
    branch = 'develop'
    ```

2. Clone all repositories at once:
   ```bash
   ./bin/milka clone
   ```

3. Pull latest changes from all repositories:
   ```bash
   ./bin/milka pull
   ```

## Configuration

Milka uses a TOML file (default: `.meta/reps.toml`) to define which repositories to manage.

### Configuration File Format

The configuration file uses the following format:

```toml
[[repo]]
dir = 'directory-name'           # Local directory name where the repo will be cloned
remote = 'https://github.com/username/repo.git'  # Git repository URL
branch = 'main'                  # Branch to work with (default: 'main')
# commit = ''                    # Specific commit to checkout (optional)
```

### Default Configuration Location

By default, Milka looks for configuration in `.meta/reps.toml` relative to the current working directory. You can specify a different location using the `--config` option.

## Commands

### `clone`
Clone repositories specified in the configuration file.

```bash
milka clone                    # Clone all repositories
milka clone repo-name          # Clone specific repository
milka clone --subtree          # Clone only repositories with source = "git+subtree" (new!)
```

### `fetch`
Fetch updates from remote repositories without merging.

```bash
milka fetch                    # Fetch all repositories
milka fetch repo-name          # Fetch specific repository
milka fetch --subtree          # Fetch only repositories with source = "git+subtree" (new!)
```

### `pull`
Pull latest changes from remote repositories.

```bash
milka pull                     # Pull all repositories
milka pull repo-name           # Pull specific repository
milka pull --subtree           # Pull only repositories with source = "git+subtree" (new!)
```

### `push`
Push local changes to remote repositories.

```bash
milka push                     # Push all repositories
milka push repo-name           # Push specific repository
milka push --subtree           # Push only repositories with source = "git+subtree" (new!)
```

### `init`
Initialize a new configuration file for managing repositories.

```bash
milka init                     # Create a new .meta/reps.toml configuration file with template
```

### `scan`
Scan current directory for git repositories and add them to the configuration file.

```bash
milka scan                     # Scan and add git repos to config (with source = "git")
milka scan --subtree           # Scan and add git repos to config (with source = "git+subtree")
```

### `help`
Show usage information.

```bash
milka help                     # Show help message
```

## Options

- `--config <path>`: Specify custom path to configuration file (default: `./.meta/reps.toml`)
- `--branch <branch>`: Override branch for operations (default: branch from config or 'main')
- `--subtree`: With scan: Add repositories with `source = "git+subtree"` (default: "git")

## Usage Examples

Clone all configured repositories:
```bash
milka clone
```

Clone a specific repository:
```bash
milka clone my-repo
```

Pull changes from all repositories:
```bash
milka pull
```

Fetch updates for a specific repository:
```bash
milka fetch my-repo
```

Push changes to all repositories:
```bash
milka push
```

Pull changes from all repositories using a specific branch:
```bash
milka --branch develop pull
```

Use a custom configuration file:
```bash
milka --config /path/to/custom.toml pull
```

Scan current directory and add git repositories to configuration:
```bash
milka scan                     # Add repos plane, not git init 
milka scan --subtree           # Add repos with subtree functionality
```

## Author

Milka is developed by Konrad Geletey <kg@re128.org>.

## License

This project is licensed under the ISC License. See the [LICENSE](LICENSE) file for details.
