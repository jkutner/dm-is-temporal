require 'spec_helper'


class MyModel
  include DataMapper::Resource

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

    it "version has the right parent" do
      subject.foo = 42
      subject.instance_eval { puts self.temporal_versions[0].my_model_id.should == self.id}
    end

    it "update all still works for non-temporal properties" do
      pending
      MyModel.update(:name => 'all the same')

      subject.name.should == 'all the same'
    end

    it "select all still works for non-temporal properties" do
      subject.name = 'looking for me!'
      subject.save
      all = MyModel.all(:name => 'looking for me!')
      all.size.should == 1
      all[0].name.should == 'looking for me!'
    end

    context "non-temporal properties" do
      it "should work as normal" do
        subject.name = 'foo'
        subject.name.should == 'foo'

        subject.name = 'bar'
        subject.name.should == 'bar'
      end

      it "should work when accessed via at(time)" do
        oldish = DateTime.parse('-4712-01-01T00:00:00+00:00')
        nowish = DateTime.parse('2011-03-01T00:00:00+00:00')
        future = DateTime.parse('4712-01-01T00:00:00+00:00')

        subject.at(oldish).name = 'foo'

        subject.at(oldish).name.should == 'foo'
        subject.at(nowish).name.should == 'foo'
        subject.at(future).name.should == 'foo'

        subject.at(nowish).name = 'bar'

        subject.at(oldish).name.should == 'bar'
        subject.at(nowish).name.should == 'bar'
        subject.at(future).name.should == 'bar'

        subject.name = 'rat'

        subject.at(oldish).name.should == 'rat'
        subject.at(nowish).name.should == 'rat'
        subject.at(future).name.should == 'rat'    
      end
    end

    context "setting temporal properties" do
      it "works" do
        oldish = DateTime.parse('-4712-01-01T00:00:00+00:00')
        nowish = DateTime.parse('2011-03-01T00:00:00+00:00')
        future = DateTime.parse('4712-01-01T00:00:00+00:00')

        subject.at(oldish).foo = 42

        subject.at(oldish).foo.should == 42
        subject.at(nowish).foo.should == 42
        subject.at(future).foo.should == 42

        subject.at(nowish).foo = 1024

        subject.at(oldish).foo.should == 42
        subject.at(nowish).foo.should == 1024
        subject.at(future).foo.should == 1024

        subject.at(future).foo = 3

        subject.at(oldish).foo.should == 42
        subject.at(nowish).foo.should == 1024
        subject.at(future).foo.should == 3

        subject.instance_eval { puts self.temporal_versions.size.should == 3}
      end

      it "and rewriting works" do
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(now).foo = 42
        subject.at(now).foo.should == 42

        subject.at(now).foo = 1
        subject.at(now).foo.should == 1
      end
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

        subject.foo = 1024
        subject.foo.should == 1024

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