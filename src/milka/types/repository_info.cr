class RepositoryInfo
  property name : String
  property url : String
  property branch : String
  property latest_commit : String
  property local_path : String
  property source : String

  def initialize(@name : String, @url : String, @branch : String = "main", @latest_commit : String = "", @source : String = "git")
    @local_path = name
  end
end
