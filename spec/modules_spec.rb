## rspec tests for Pebbl App support modules

require 'pebbl_app/project/project_module'

## the libraries to test
require 'pebbl_app/support'
require 'pebbl_app/gtk_support'

shared_examples_for 'a project module' do |conf|
  let(:ns) { conf[:ns] }

  it "defines an exsisting source_path" do
    expect(ns.source_path).to_not be_falsey
    expect(File.exist?(ns.source_path)).to be true
  end

  it "defines autoloads for existing files" do
    dir = ns.source_path
    ns.autoloads.each do |name, file|
      if !File.exist?(File.expand_path(file, dir))
        RSpec::Expectations.fail_with(
          "Autoload file for %s does not exist: %p" % [
            name, file
          ])
      end
    end
  end
end

describe PebblApp::Support do
  it_behaves_like  'a project module', ns: described_class
end

describe PebblApp::GtkSupport do
  it_behaves_like  'a project module', ns: described_class
end
