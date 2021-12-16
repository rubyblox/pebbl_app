## test/basedir.rb

require 'basedir.rb' # the library to test

class TestClass
  extend FileResourceManager ## the module to teset ...
end

describe TestClass do
  it "uses a correct default resource_root" do
    ## FIXME fails
    expect(described_class.resource_root).
      to be == File.dirname(__FILE__)
  end
end

## Local Variables:
## fill-column: 65
## End:
