require 'spec_helper'

module Assoc
  class Foobar
    include DataMapper::Resource

    property :id, Serial
    property :baz, String

    # todo bi-direction temporal relationships
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
      has n, :foobazes, 'Foobar'
    end
  end
end

describe DataMapper::Is::Temporal do

  before(:all) do
    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:test, "sqlite3::memory:")
  end
  
  before(:each) do
    DataMapper.auto_migrate!
  end

  describe "#has" do

    context "with defaults" do
      subject do
        Assoc::MyModel.create
      end

      it "adds a Foobar at the current time" do
        f = Assoc::Foobar.create(:baz => "hello")
        subject.foobars << f
        subject.save
        subject.foobars.size.should == 1
        subject.foobars.should include(f)

        subject.instance_eval { self.temporal_foobars.size.should == 1}
      end

      it "adds a couple Foobars at different times" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.save
        subject.at(old).foobars.size.should == 1

        subject.instance_eval { self.temporal_foobars.size.should == 1}

        subject.at(now).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save
        subject.at(now).foobars.size.should == 2

        subject.instance_eval { self.temporal_foobars.size.should == 2}

        subject.foobars.should include(f1, f2)
      end

      it "adds a couple Foobars at the same time" do
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(now) do |m|
          m.foobars << Assoc::Foobar.create(:baz => "hello")
          m.foobars << Assoc::Foobar.create(:baz => "goodbye")
        end
        subject.save

        subject.at(now).foobars.size.should == 2
        subject.instance_eval { self.temporal_foobars.size.should == 2}
      end
    end

    context "with explicit class" do
      subject do
        Assoc::MyModelTwo.create
      end

      it "adds a Foobar at the current time" do
        f = Assoc::Foobar.create(:baz => "hello")
        subject.foobazes << f
        subject.save
        subject.foobazes.size.should == 1
        subject.foobazes.should include(f)

        subject.instance_eval { self.temporal_foobazes.size.should == 1}
      end

      it "adds a couple Foobars at different times" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobazes << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.save
        subject.at(old).foobazes.size.should == 1

        subject.instance_eval { self.temporal_foobazes.size.should == 1}

        subject.at(now).foobazes << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save
        subject.at(now).foobazes.size.should == 2

        subject.instance_eval { self.temporal_foobazes.size.should == 2}

        subject.foobazes.should include(f1, f2)
      end

      it "adds a couple Foobars at the same time" do
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(now) do |m|
          m.foobazes << Assoc::Foobar.create(:baz => "hello")
          m.foobazes << Assoc::Foobar.create(:baz => "goodbye")
        end
        subject.save

        subject.at(now).foobazes.size.should == 2
        subject.instance_eval { self.temporal_foobazes.size.should == 2}
      end
    end
  end
end