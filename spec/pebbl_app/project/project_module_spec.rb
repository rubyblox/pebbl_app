## RSpec for PebblApp::ProjectModule

## test with the following, under the project root directory
##
## $ bundle exec rake --trace spec
##

describe %(Module includes PebblApp::ProjectModule) do
  let(:subject) {
    module ProjectModuleTests01
      include PebblApp::ProjectModule
    end
  }

  it "Initializes a source_path on first access" do
    expect(subject.instance_variable_defined?(:@source_path)).to_not be true
    ## accesses the instance varible
    expect(subject.source_path).to be == __dir__
    ## tests that the variable is now defined
    expect(subject.instance_variable_defined?(:@source_path)).to be true
  end

  it "Uses a suffix .rb in autoload_source_path" do
    expect(File.extname(subject.autoload_source_path("a"))).to be == ".rb"
    expect(File.extname(subject.autoload_source_path("b.rb"))).to be == ".rb"
  end

  it "Configures Autoloads" do
    subject.defautoload("nonexistent_a", :NonexistentA)
    subject.defautoload("nonexistent_b.rb", :NonexistentB)

    expect(subject.autoload?(:NonexistentA)).
      to be == File.expand_path("nonexistent_a.rb", __dir__)
    expect(subject.autoload?(:NonexistentB)).
      to be == File.expand_path("nonexistent_b.rb", __dir__)
  end


  it "uses source_path as a base directory for autoloads" do
    subject.defautoload("nonexistent_a", :NonexistentA)
    subject.defautoload("nonexistent_b.rb", :NonexistentB)
    expect(File.dirname(subject.autoload?(:NonexistentA))).
      to be == subject.source_path
    expect(File.dirname(subject.autoload?(:NonexistentB))).
      to be == subject.source_path
  end


  it "uses filename as a base name for autoloads" do
    subject.defautoload("nonexistent_a", :NonexistentA)
    subject.defautoload("nonexistent_b.rb", :NonexistentB)
    expect(File.basename(subject.autoload?(:NonexistentA))).
      to be == "nonexistent_a.rb"
    expect(File.basename(subject.autoload?(:NonexistentB))).
      to be == "nonexistent_b.rb"
  end


  it "Defers Autoloads" do
    subject.autoloads_defer = true
    subject.defautoload("nonexistent_c", :NonexistentC)
    subject.defautoload("nonexistent_d.rb", :NonexistentD)
    expect(subject.autoload?(:NonexistentC)).to be nil
    expect(subject.autoload?(:NonexistentD)).to be nil
    subject.autoloads_apply
    expect(subject.autoload?(:NonexistentC)).
      to be == File.expand_path("nonexistent_c.rb", __dir__)
    expect(subject.autoload?(:NonexistentD)).
      to be == File.expand_path("nonexistent_d.rb", __dir__)
    subject.autoloads_defer = false
  end

  it "Accepts and applies a different source_path" do
    expect(subject.source_path).to be == __dir__
    subject.source_path = "/nonexistent"
    subject.defautoload("nonexistent_e", :NonexistentE)
    subject.defautoload("nonexistent_f.rb", :NonexistentF)
    expect(subject.autoload?(:NonexistentE)).
      to be == File.expand_path("nonexistent_e.rb", "/nonexistent")
    expect(subject.autoload?(:NonexistentF)).
      to be == File.expand_path("nonexistent_f.rb", "/nonexistent")
    subject.source_path = __dir__
  end

end
