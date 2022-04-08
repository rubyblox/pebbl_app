## projectfile.rb

module RbProject

  class ProjectFile < File
    def get_version
      return "TBD"
    end
    def get_git_tags
    end
    def get_version_git(tag)
    end
  end

  class RubyFile < ProjectFile
  end

end ## module RbProject
