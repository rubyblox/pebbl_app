## rspec tests for project gemspecs

## FIXME should be evaluated after tests for YSpec

require 'pebbl_app/project/y_spec'

data_file = File.join($DATA_ROOT, "project.yaml")
if File.exists?(data_file)
  $YSPEC= PebblApp::Project::YSpec.new(data_file)
else
   RSpec::Expectations.fail_with("Project data not found: #{data_file}")
end

shared_examples_for "a project gemspec" do |conf|
  let!(:specname) { conf[:name] }
  let!(:specfile) { File.join($DATA_ROOT, specname + ".gemspec") }
  let(:cached_spec) { Gem::Specification.find_by_name(specname) }

  it "has an existing set of files" do
    basedir = cached_spec.full_gem_path
    cached_spec.files.each do |f|
      path = File.join(basedir,f)
      if !File.exists?(path)
        RSpec::Expectations.fail_with("File does not exist: #{f}")
      end
    end
  end
end

$YSPEC.gems.each do |name|
  describe "#{name}.gemspec" do
    it_behaves_like "a project gemspec", name: name
  end
end
