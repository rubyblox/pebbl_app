## ApiDb tests (sandbox)

require_relative 'api-yardwalk'

orig_dbg = $DEBUG

## traversal for one gem, by default: gio2
##
## test also with, e.g 'glib2', 'gtk3', 'vte3', ...
##

gem = (ENV['TRAVERSE_GEM'] || 'gio2')

begin
  $DEBUG = true
  spec = Gem::Specification.find_by_name(gem)
  traversal = ApiDb::YardWalk.new
  # traversal.bind_preload do |rb_obj, code_obj|
  #   ## TBD preloading for GIR-based submodules of GLib2
  # end
  traversal.traverse_spec(spec) do |rb_obj, code_obj|
    if (YARD::CodeObjects::MethodObject === code_obj)
      extra = " (#{code_obj.scope} scope)"
    else
      extra = "".freeze
    end
    STDERR.puts "Traversed %s%s => %p" % [
      code_obj.path, extra, rb_obj
    ]
  end
ensure
  $DEBUG = orig_dbg
end
