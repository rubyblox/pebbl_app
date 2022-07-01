## rspec tests for pebbl_app/gtk_framework/gir_proxy.rb

## dependencies
require 'gobject-introspection'

## the library to test
require 'pebbl_app/gir_proxy'

## prerequisites for the tests
require 'gtk3'


describe PebblApp::InvokerP do
  subject {
    inst = described_class.allocate
    ## singleton method for initializing the allocated object
    def inst.init(invk)
      self.send(:initialize, invk)
      self
    end
    inst
  }
  let(:proxy_class) {
    Gdk::X11Display
  }
  let(:proxy_module) {
    Gdk
  }

  it "initializes an empty cached_invokers table" do
    expect(described_class.cached_invokers.empty?).to be true
  end

  it "implements a class method find_invoker_p" do
    expect{
      described_class.find_invoker_p(proxy_class::INVOKERS.first[1])
    }.to_not raise_error
  end

  it "implements a class method invokers_for(Class) " do
    expect{
      described_class.invokers_for(proxy_class)
    }.to_not raise_error
  end

  it "implements a class method invokers_for(Module)" do
    expect{
      described_class.invokers_for(proxy_module)
    }.to_not raise_error
  end

  it "initializes an invoker attribute for forwarding" do
    subject.init(proxy_class::INVOKERS.first[1])
    expect(subject.invoker).to_not be nil
  end

  it "provides a forwarding accessor full_method_name" do
    subject.init(proxy_class::INVOKERS.first[1])
    expect(subject.full_method_name).to_not be nil
  end

  it "provides a forwarding accessor for function info" do
    subject.init(proxy_class::INVOKERS.first[1])
    expect(subject.info).to_not be nil
  end

  it "provides a proxy accessor callable_info" do
    ## InvokerP.find_invoker_for will initialize a FuncInfo proxy
    ## on each new InvokerP. This value will also provide a proxy to the
    ## invoker's 'info' attr, with the proxy stored in the 'callable_info'
    ## attr on the InvokerP
    invk = proxy_class::INVOKERS.first[1]
    subject = described_class.find_invoker_p(invk)
    test_info = invk.instance_variable_get(:@info)
    expect(subject.callable_info).to_not equal test_info
    expect(subject.info).to equal test_info
    expect(subject.callable_info.info).to equal test_info
  end

end

describe PebblApp::FuncInfo do
  subject {
    inst = described_class.allocate
    ## singleton method for initializing the allocated object
    def inst.init(finfo)
      self.send(:initialize, finfo)
      self
    end
    inst
  }
  let(:invk) {
    Gdk::X11Display::INVOKERS.first[1]
  }

  it "initializes a cached_info table" do
    ## the cached_info table on the described class would be
    ## non-empty here. The cached_info table in this class will
    ## have been used to store *info proxy instances for earlier
    ## tests on class methods of InvokerP
    ##
    ## testing here to ensure that the cached_info table is an
    ## enumerable object
    expect(described_class.cached_info).to be_kind_of Enumerable
  end

  it "provides a class method find_callable_info(FunctionInfo)" do
    ivp = PebblApp::InvokerP.find_invoker_p(invk)
    expect(described_class.find_callable_info(ivp.info)).to_not be false
  end

  it "provides a class method find_callable_info(FunctionInfo)" do
    ivp = PebblApp::InvokerP.find_invoker_p(invk)
    expect(described_class.find_callable_info(ivp.info)).to_not be false
  end

end
