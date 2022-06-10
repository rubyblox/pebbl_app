## test/basedir.rb

## FIXME obsolete implementation @ FileResourceManager
##
## newer implementation: PebblApp::Project::ProjectModule

require 'pebbl_app/gtk_support/basedir' # the library to test

describe PebblApp::GtkSupport::FileResourceManager do
  subject{
    class TestClass
      extend PebblApp::GtkSupport::FileResourceManager ## the module to test ...
    end
    TestClass
  }
  let(:p1) { "/nonexistent.p1.d"}
  let(:p2) { "/nonexistent.p2.d" }
  let(:p3) { "file.p3" }

  ## NB TestClass will retain some state across each of the
  ## following examples, mainly in the @@resource_root and
  ## @@resource_root_locked variables in the class.
  ##
  ## The order of these examples is significant to the evaluation
  ## of the test group

  it "uses a block for unset resource_root" do
    expect( subject.resource_root { File.dirname(__FILE__) }).
      to be == __dir__
  end

  it "uses pwd for resource_root when unset (no block)" do
    module_src = described_class.method(:extended).source_location
    module_path = module_src ? module_src[0] : nil
    expect(subject.resource_root).
      to be == Dir.pwd
  end

  it "sets (unlocked) and retrieves a provided resource root" do
    expect(subject.set_resource_root(p1, true)). to be == p1
    expect(subject.resource_root).to be == p1
  end

  it "allows overriding an unlocked resource root" do
    expect(subject.set_resource_root(p2, true)).to be == p2
    expect(subject.resource_root).to be == p2
  end

  it "allows overriding and locking an unlocked resource root" do
    expect(subject.set_resource_root(p1)).to be == p1
    expect(subject.resource_root).to be == p1
  end

  it "avoids setting a locked resource root" do
    expect(subject.set_resource_root(p2, true)).to be false
    expect(subject.resource_root).to be == p1
  end

  it "expands a provided pathname" do
    expect(p4 = subject.expand_resource_path(p3)).
      to be == File.join(p1, p3)
    expect(subject.expand_resource_path(p4)).
      to be == p4
  end

end

## Local Variables:
## fill-column: 65
## End:
