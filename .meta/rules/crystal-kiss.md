# Crystal Style Guide for Milka Project - KISS (Keep It Simple, Stupid) Principle
# Clear Functions and Proper Typings

## Naming Conventions

- Use snake_case for methods and variables
- Use PascalCase for classes and modules
- Use descriptive but concise names

## Type Annotations

- Always specify return types for public methods
- Use specific types instead of generic unions where possible
- Leverage Crystal's type inference for local variables when types are obvious

## Examples of Clear, Well-Typed Functions

### Good: Simple function with clear typing

```crystal
def calculate_repository_count(repositories : Array(RepositoryInfo)) : Int32
  repositories.size
end
```

### Good: Function with optional parameter and return type

```crystal
def find_repository_by_name(repositories : Array(RepositoryInfo), name : String) : RepositoryInfo?
  repositories.find { |repo| repo.name == name }
end
```

### Good: Boolean method with descriptive name ending in "?"

```crystal
def valid_repository_url?(url : String) : Bool
  url.starts_with?("http") && url.includes?(".git")
end
```

### Good: Class with clearly typed properties

```crystal
class RepositoryStats
  property repository : RepositoryInfo
  property commit_count : Int32
  property last_updated : Time

  def initialize(@repository : RepositoryInfo, @commit_count : Int32 = 0, @last_updated : Time = Time.local)
  end

  def stale?(days : Int32 = 7) : Bool
    (Time.local - @last_updated).days > days
  end
end
```

### Good: Module with namespaced functions

```crystal
module RepositoryHelpers
  def self.is_local_repo?(path : String) : Bool
    Dir.exists?(path) && Dir.children(path).includes?(".git")
  end

  def self.format_repo_path(name : String, base_path : String = "./repos") : String
    "#{base_path}/#{name}"
  end
end
```

### Good: Error handling with proper types

```crystal
class RepositoryError < Exception
  property code : Int32
  property repo_name : String

  def initialize(message : String, @code : Int32, @repo_name : String)
    super(message)
  end
end
```

### Good: Working with collections with proper typing

```crystal
def get_active_repositories(repositories : Array(RepositoryInfo), active_branches : Array(String)) : Array(RepositoryInfo)
  repositories.select { |repo| active_branches.includes?(repo.branch) }
end
```

### Good: Method that returns multiple values using named tuple (Crystal feature)

```crystal
def analyze_repository(repo : RepositoryInfo) : {files_count: Int32, size_mb: Float64}
  files_count = count_files_in_repo(repo.local_path)
  size_mb = calculate_repo_size_mb(repo.local_path)
  
  {files_count: files_count, size_mb: size_mb}
end
```

## Following KISS principles:

1. Each function has a single, clear purpose
2. Type annotations make the interface explicit
3. Names clearly describe what the function does
4. Methods are short and focused
5. Complex logic is broken down into smaller, composable functions