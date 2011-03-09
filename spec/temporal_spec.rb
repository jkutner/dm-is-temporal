require 'spec_helper'


class MyModel
  include DataMapper::Resource

#  def self.default_repository_name
#    :test
#  end

  property :id, Serial
  property :name, String

  is_temporal do
    property :foo, Integer
    property :bar, String
  end
end

class MyOtherRepoModel
  include DataMapper::Resource

  def self.default_repository_name
    :test
  end

  property :id, Serial
  property :name, String

  is_temporal do
    property :foo, Integer
  end
end

describe DataMapper::Is::Temporal do

  before(:all) do
    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:test, "sqlite3::memory:")
    DataMapper.auto_migrate!(:default)
    DataMapper.auto_migrate!(:test)
  end

  describe "#is_temporal" do

    subject do
      MyModel.create
    end

    context "when at context" do
      it "returns old values" do
        subject.foo.should == nil
        subject.foo = 42
        subject.foo.should == 42

        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.now

        subject.at(old).foo.should == nil
        subject.at(now).foo.should == 42
      end
    end

    context "when foo is 42" do
      it "returns 42" do
        subject.foo.should == nil
        subject.foo = 42
        subject.foo.should == 42
      end

      it "returns 'same' for bar" do
        subject.bar = 'same'
        subject.bar.should == 'same'
        subject.foo.should == nil
        subject.foo = 42
        subject.foo.should == 42
        subject.bar.should == 'same'
      end
    end

    context "when bar is 'hello'" do
      it "returns 'hello' and then 'goodbye'" do
        subject.bar.should == nil
        subject.bar = 'hello'
        subject.bar.should == 'hello'
        subject.bar = 'goodbye'
        subject.bar.should == 'goodbye'
      end
    end

    context "when name is 'hello'" do
      it "returns 'hello' and then 'goodbye'" do
        subject.name.should == nil
        subject.name = 'hello'
        subject.name.should == 'hello'
        subject.name = 'goodbye'
        subject.name.should == 'goodbye'
      end
    end

    context "when updated" do
      it "all values set and reset" do
        subject.update(
            :foo => 42,
            :bar => 'hello',
            :name => 'joe'
        )

        subject.foo.should == 42
        subject.bar.should == 'hello'
        subject.name.should == 'joe'
      end
    end

    context "when churnned" do
      it "has many versions" do
        subject.foo = 1
        subject.foo = 2
        subject.foo = 3
        subject.foo = 4

        subject.instance_eval {self.temporal_versions.size.should == 4}
      end
    end

    context "when class create with options" do
      it "return all values" do
        m = MyModel.create(
            :foo => 42,
            :bar => 'hello',
            :name => 'joe'
        )

        m.foo.should == 42
        m.bar.should == 'hello'
        m.name.should == 'joe'

        m.foo = 10
        m.foo.should == 10
      end
    end

    context "when repository name is set" do
      it "MyModel returns :default" do
        MyModel::TemporalVersion.default_repository_name.should == :default
      end

      it "MyOtherRepoModel returns :test" do
        MyOtherRepoModel::TemporalVersion.default_repository_name.should == :test
      end

      context "when name is 'hello'" do
        subject do
          MyOtherRepoModel.create
        end

        it "returns 'hello' and then 'goodbye'" do
          subject.name.should == nil
          subject.name = 'hello'
          subject.name.should == 'hello'
          subject.name = 'goodbye'
          subject.name.should == 'goodbye'
        end
      end

      context "when updated" do
        it "all values set and reset" do
          subject.update(
              :foo => 42,
              :name => 'joe'
          )

          subject.foo.should == 42
          subject.name.should == 'joe'
        end
      end
    end
  end
end