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

describe DataMapper::Is::Temporal do

  before(:all) do 
    DataMapper.setup(:default, "sqlite3::memory:")
    DataMapper.auto_migrate!
  end
  
  describe"#is_temporal" do
  
  	subject do
  	  MyModel.create
  	end
  
  	context "when foo is 42" do  	
		it "returns 42" do
		  subject.foo.should == nil
		  subject.foo = 42
		  subject.foo.should == 42
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
  end
end