require 'spec_helper'

module Hooks
  class MyModel
    include DataMapper::Resource

    property :id, Serial
    property :name, String

    is_temporal do
      property :foo, Integer
      property :bar, String

      before(:save) do |m|
        m.foo = 42
      end

      after(:create) do |m|
        m.bar = 'hello'
      end
    end
  end
end

describe DataMapper::Is::Temporal do

  before(:all) do
    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:test, "sqlite3::memory:")
  end
  
  before  (:each) do
    DataMapper.auto_migrate!
  end

  describe "#before" do

    subject do
      Hooks::MyModel.create
    end

    it "before hook sets foo to 42" do
      subject.foo = 10
      subject.save
      subject.foo.should == 42
    end

    it "bar should == 'hello'" do
      subject.foo = 10
      subject.save
      subject.bar.should == 'hello'
    end


    it "bar should == 'hello' even if changed" do
      oldish = DateTime.parse('-4712-01-01T00:00:00+00:00')
      nowish = DateTime.parse('2011-03-01T00:00:00+00:00')

      subject.at(oldish).bar = 'quack'
      subject.save
      subject.at(oldish).bar.should == 'hello'

      subject.instance_eval { self.temporal_versions.size.should == 1}

      subject.at(nowish).bar = 'quack'
      subject.save
      subject.at(nowish).bar.should == 'quack'
      subject.at(oldish).bar.should == 'hello'

      subject.instance_eval { self.temporal_versions.size.should == 2}
    end
  end
end