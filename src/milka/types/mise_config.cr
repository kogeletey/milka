class MiseConfig
  property repositories : Array(RepositoryInfo)
  property default_branch : String
  property env : Hash(String, String)?

  def initialize(@repositories : Array(RepositoryInfo), @default_branch : String, @env : Hash(String, String)?)
  end
end
