## project_tools.rb

module Project
  def self.filename_no_suffix(f)
    name = File.basename(f)
    ext = File.extname(name)
    if ext.length < name.length
      name[...-ext.length]
    else
      name
    end
  end

  def self.gemspec_common_config(s, basedir, lib_module,
                                 libname: File.basename(basedir),
                                 extra_files: [])
    lib_name = lib_module.name.downcase
    version_file = File.join( "lib", lib_name, lib_name + "_version.inc")
    module_file = File.join("lib", lib_name + ".rb")

    s.name = lib_name
    s.version = File.read(File.join(basedir, version_file)).
                  split("\n").grep(/^[[:space:]]*[^#]/).first.strip

    s.licenses=%w(MPL-2.0)
    author_name = IO.read('|git config user.name').chomp
    author_email = IO.read('|git config user.email').chomp
    s.authors = [author_name]
    s.email = [author_email]
    s.summary = lib_name + " gem"

    if lib_module.const_defined?(:AUTOLOAD_MAP)
      class_files = lib_module::AUTOLOAD_MAP.map { |file, names|
        File.join("lib", lib_name, file + ".rb")
      }
    elsif lib_module.const_defined?(:AUTOLOAD_CLASSES)
      class_files = lib_module::AUTOLOAD_CLASSES.map { |name|
        File.join("lib", lib_name, name.downcase + ".rb")
      }
    else
      class_files=[]
    end

    s.files=[module_file, version_file].concat(class_files).
              concat(extra_files.dup)

    s.require_paths = ["lib", File.join("lib", lib_name)]

  end
end
