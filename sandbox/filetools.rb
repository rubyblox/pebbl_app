## filetools.rb (sandbox) --- catch-bin for local file utilities

module FileTools

def self.get_pathname(path)
  ## FIXME unused. see also .base_relative_path
  if (Pathname === path)
    return path
  else
    return Pathname.new(path)
  end
end

## return a {Pathname} for PATH as relative to BASEPATH
##
## @param path [String, Pathname] pathname for the relative path
## @param basepath [String, Pathname] base pathname for the relative path
## @return [Pathname] relative pathname
def self.base_relative_path(path, basepath = File.dirname(__FILE__ ))
  ## FIXME unused

  ## FIXME ensure this uses __FILE__ as at when it's evaluated
  ## not when it's parsed from the definition here, or simply
  ## remove the defaulting for the basepath param
  STDERR.puts "base_relative_path path: #{path}" if $DEBUG
  base_p = get_pathname(basepath).expand_path
  STDERR.puts "base_relative_path base_p: #{base_p}" if $DEBUG
  path_p = get_pathname(path).expand_path
  return base_p.relative_path_from(path_p)
end

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


end ## FileTools module
