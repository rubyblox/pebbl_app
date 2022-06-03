## project.rb --- module definition for ThinkumSpace::Project

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory. The module may define autoloads that would be
  ## used in this file.
  require(__dir__ + ".rb")
}

module ThinkumSpace::Project
  autoload(:Ruby, File.join(__dir__, 'project/ruby.rb'))
  autoload(:ProjectModule, File.join(__dir__, 'project/project_module.rb'))

  ## utility forms (FIXME move to some sublcass)
  def self.filename_no_suffix(f)
    name = File.basename(f)
    ext = File.extname(name)
    extlen = ext.length
    if extlen.eql? 0
      return name
    elsif extlen < name.length
      return name[...-extlen]
    else
      return name
    end
  end

end

