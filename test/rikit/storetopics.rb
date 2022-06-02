## storetopics.rb (rspec tests)

shared_examples_for RIKit::NamespaceTopic do

  it "initializes namespace storage" do
    expect(subject.instance_variables).to include(:@ns_members)
    expect(subject.instance_variable.get(:@ns_members)).to_not be nil
  end

  it "stores recognized element kinds" do
    described_class::NS_ELEMENT_KINDS.index { |idx|
      expect(described_class::NS_ELEMENT_KINDS(idx)).to be_instance_of(Symbol)
    }
  end

  it "returns a class for each recognized element kind" do
    described_class::NS_ELEMENT_KINDS.each { |kind|
      expect(described_class.kind_class(kind)).to be_instance_of(Class)
    }
  end

  it "registers an instance for every recognized element kind" do
    names = []
    instances = []
    described_class::NS_ELEMENT_KINDS.each { |kind|
      name = "B_%s" % [kind]
      names.push(name)
      nxt_b = described_class.kind_class(kind).
                new(subject, name)
      instances.push(nxt_b)
      subject.use_ns_element(nxt_b)
    }

    expect(obj_a.ns_names).to match_array(names)
    expect(obj_a.ns_members).to match_array(instances)

    expect(obj_ab.namespace).to be obj_a
  end

end

shared_examples_for RIKit::TypedTopic do
  it "initializes namespace storage" do
    expect(subject.instance_variables).to include(:@type_members)
    expect(subject.instance_variable.get(:@type_members)).to_not be nil
  end
end

shared_examples_for RIKit::TypedNamespaceTopic do
  context "Object initialization" do
    it_should_behave_like RIKit::NamespaceTopic
    it_should_behave_like RIKit::TypedTopic
  end
end

describe RIKit::ModuleTopic do
  context "common behaviors" do
    it_should_behave_like RIKit::NamespaceTopic
  end
end

describe RIKit::ClassTopic do
  context "common behaviors" do
    it_should_behave_like RIKit::NamespaceTopic
  end
end


describe RIKit::RITopicRegistry do
  let(:namespace_iv) { :@namespaces }
  let(:topic_abc) { "A::B::C" }
  let(:topic_abcd) { topic_abc + "::D" }
  let(:topic_abc_abs) { "::A::B::C" }
  let(:topic_mno) { "M::N::O" }

  context "common behaviors" do
    it_should_behave_like RIKit::NamespaceTopic
  end

  it "registers a module" do
    mod_z_first = subject.register_module("Z")
    expect(subject.find_ns_element("Z")).
      to be == mod_z_first
  end

  it "registers a module tree" do
    mod_abc = subject.register_module(topic_abc)
    expect(subject.ns_names).to_not be_empty
    expect(subject.ns_members).to_not be_empty
    expect(topic_a = subject.find_ns_element("A")).
      to be_truthy
    expect(topic_b = topic_a.find_ns_element("B")).
      to be_truthy
    expect(topic_b.find_ns_element("C")).
      to be == mod_abc
  end

  it "registers a module tree with absolute name" do
    mod_abc = subject.register_module(topic_abc_abs)
    expect(subject.namespaces).to_not be_empty
    expect(topic_a = subject.find_ns_element("A")).
      to be_truthy
    expect(topic_b = topic_a.find_ns_element("B")).
      to be_truthy
    expect(topic_b.find_ns_element("C")).
      to be == mod_abc
  end

  it "locates a registered module" do
    mod_abc = subject.register_module(topic_abc)
    ## FIXME fails
    expect(subject.find_ns_element(topic_abc)).
      to be == mod_abc
  end

  it "converts a topic in direct call" do
    ## FIXME implement
    cls_abc = subject.convert_ns_topic(:class, mod_abc)

    expect(cls_abc).to_not be == mod_abc
    expect(cls_abc.class).to eql :class
    expect(cls_abc.name).to eql mod_abc.name
    # expect(cls_abc. ...
  end


  ## FIXME implement
  it "converts an out-of-scope topic" do
    mod_abc = subject.register_module(topic_abc)
    # expect(subject.convert_ns_topic(:class, mod_abc)).to ...

    mod_abcd = subject.register_module(topic_abcd)
    expect(mod_abc.kind).to eql(:module)
  end
end

