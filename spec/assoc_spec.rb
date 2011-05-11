require 'spec_helper'

class Foobar
  include DataMapper::Resource

  property :id, Serial
  property :baz, String

  # todo
#  belongs_to :my_model
end

class MyModel
  include DataMapper::Resource

  property :id, Serial
  property :name, String

  is_temporal do
    has n, :foobars
  end
end

class MyModelTwo
  include DataMapper::Resource

  property :id, Serial
  property :name, String

  is_temporal do
    has n, :foobazes, '::Foobar'
  end
end

describe DataMapper::Is::Temporal do

  before(:all) do
    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.finalize
    DataMapper.auto_migrate!
  end

  describe "#has" do

    context "with defaults" do
      subject do
        MyModel.create
      end

      it "adds a Foobar at the current time" do
        subject.foobars << Foobar.create(:baz => "hello")
        subject.save
        subject.foobars.size.should == 1

        subject.instance_eval { self.temporal_versions.size.should == 1}
      end

      it "adds a couple Foobars at different times" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << Foobar.create(:baz => "hello")
        subject.save
        subject.at(old).foobars.size.should == 1

        subject.instance_eval { self.temporal_versions.size.should == 1}

        subject.at(now).foobars << Foobar.create(:baz => "goodbye")
        subject.save
        subject.at(now).foobars.size.should == 2

        subject.instance_eval { self.temporal_versions.size.should == 2}
      end

      it "adds a couple Foobars at the same time" do
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(now) do |m|
          m.foobars << Foobar.create(:baz => "hello")
          m.foobars << Foobar.create(:baz => "goodbye")
        end
        subject.save

        subject.at(now).foobars.size.should == 2
        subject.instance_eval { self.temporal_versions.size.should == 1}
      end
    end

    context "with explicit class" do
      subject do
        MyModelTwo.create
      end

      it "adds a Foobar at the current time" do
        subject.foobazes << Foobar.create(:baz => "hello")
        subject.save
        subject.foobazes.size.should == 1

        subject.instance_eval { self.temporal_versions.size.should == 1}
      end

      it "adds a couple Foobars at different times" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobazes << Foobar.create(:baz => "hello")
        subject.save
        subject.at(old).foobazes.size.should == 1

        subject.instance_eval { self.temporal_versions.size.should == 1}

        subject.at(now).foobazes << Foobar.create(:baz => "goodbye")
        subject.save
        subject.at(now).foobazes.size.should == 2

        subject.instance_eval { self.temporal_versions.size.should == 2}
      end

      it "adds a couple Foobars at the same time" do
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(now) do |m|
          m.foobazes << Foobar.create(:baz => "hello")
          m.foobazes << Foobar.create(:baz => "goodbye")
        end
        subject.save

        subject.at(now).foobazes.size.should == 2
        subject.instance_eval { self.temporal_versions.size.should == 1}
      end
    end
  end
end