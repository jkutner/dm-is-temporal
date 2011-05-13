require 'spec_helper'

module Assoc
  class Foobar
    include DataMapper::Resource

    property :id, Serial
    property :baz, String

    belongs_to :my_model
  end

  class ThreeFoobar
    include DataMapper::Resource
    property :id, Serial
    property :version, DateTime
    belongs_to :foobar
    belongs_to :my_model_three
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

  class MyModelThree
    include DataMapper::Resource

    property :id, Serial

    is_temporal do
      property :name, String
      has n, :three_foobars
    end
  end
end

describe DataMapper::Is::Temporal do

  before(:all) do
#    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.setup(:default, "postgres://localhost/dm_is_temporal")
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

        f.my_model.should == subject
      end

      it "adds a couple Foobars at different times" do
        bot = DateTime.parse('-4712-01-01T00:00:00+00:00')
        old = DateTime.parse('-2011-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.save
        subject.at(old).foobars.size.should == 1

        subject.instance_eval { self.temporal_foobars.size.should == 1}

        subject.at(now).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(bot).foobars.size.should == 0
        subject.at(old).foobars.size.should == 1
        subject.at(now).foobars.size.should == 2

        subject.instance_eval { self.temporal_foobars.size.should == 2}

        subject.foobars.should include(f1, f2)
      end

      it "pops" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.at(old).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(old).foobars.should include(f1, f2)
        subject.at(now).foobars.should include(f1, f2)

        subject.at(old).foobars.pop

        subject.at(old).foobars.size.should == 1
        subject.at(now).foobars.size.should == 1
        subject.foobars.size.should == 1
      end

      it "pops and has proper state before and after" do
        bot = DateTime.parse('-4712-01-01T00:00:00+00:00')
        old = DateTime.parse('-2011-01-01T00:00:00+00:00')
        mid = DateTime.parse('0000-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.at(old).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(bot).foobars.size.should == 0
        subject.at(old).foobars.should include(f1, f2)
        subject.at(mid).foobars.should include(f1, f2)
        subject.at(now).foobars.should include(f1, f2)

        subject.at(mid).foobars.pop

        subject.at(bot).foobars.size.should == 0
        subject.at(old).foobars.size.should == 2
        subject.at(mid).foobars.size.should == 1
        subject.at(now).foobars.size.should == 1
        subject.foobars.size.should == 1
      end

      it "deletes" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.at(old).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(old).foobars.should include(f1, f2)

        subject.at(old).foobars.delete(f1)

        subject.at(old).foobars.size.should == 1
        subject.at(now).foobars.size.should == 1
        subject.foobars.size.should == 1
        subject.at(old).foobars.should include(f2)
        subject.at(now).foobars.should include(f2)
        subject.foobars.should include(f2)

        subject.at(old).foobars.delete(f2)

        subject.at(old).foobars.size.should == 0
        subject.at(now).foobars.size.should == 0
        subject.foobars.size.should == 0
      end

      it "delete_if" do
        old = DateTime.parse('-4712-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.at(old).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(old).foobars.should include(f1, f2)

        subject.at(old).foobars.delete_if do |f|
          f.baz == 'hello'
        end
        subject.save

        subject.at(old).foobars.size.should == 1
        subject.at(now).foobars.size.should == 1
        subject.foobars.size.should == 1
        subject.at(old).foobars.should include(f2)
        subject.at(now).foobars.should include(f2)
        subject.foobars.should include(f2)
      end

      it "clears" do
        bot = DateTime.parse('-4712-01-01T00:00:00+00:00')
        old = DateTime.parse('-2011-01-01T00:00:00+00:00')
        mid = DateTime.parse('0000-01-01T00:00:00+00:00')
        now = DateTime.parse('2011-03-01T00:00:00+00:00')

        subject.at(old).foobars << f1 = Assoc::Foobar.create(:baz => "hello")
        subject.at(old).foobars << f2 = Assoc::Foobar.create(:baz => "goodbye")
        subject.save

        subject.at(old).foobars.should include(f1, f2)

        subject.at(mid).foobars.clear
        subject.save

        subject.at(bot).foobars.size.should == 0
        subject.at(old).foobars.size.should == 2
        subject.at(mid).foobars.size.should == 0
        subject.at(now).foobars.size.should == 0
        subject.foobars.size.should == 0
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

    context "with join class" do
      subject do
        Assoc::MyModelThree.create
      end

      it "adds a Foobar at the current time" do
        f = Assoc::Foobar.create(:baz => "hello")
        join = Assoc::ThreeFoobar.create(:foobar => f)
        subject.three_foobars << join
        subject.save
        subject.three_foobars.size.should == 1
        subject.three_foobars.should include(join)

        subject.instance_eval { self.temporal_three_foobars.size.should == 1}

        x = DataMapper.repository(:default).adapter.select("select * from assoc_my_model_three_temporal_three_foobars")
        puts "x=#{x.inspect}"
      end
    end
  end
end