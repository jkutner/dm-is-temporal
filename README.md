dm-is-temporal
==================================

DataMapper plugin implementing temporal patterns on DataMapper models.

These patterns are based on research by Martin Fowler, Richard Snodgrass and others.  For more information follow these links:

+  [Temporal Patterns](http://martinfowler.com/eaaDev/timeNarrative.html)

+  [Developing Time-Oriented Database Applications in SQL](http://www.cs.arizona.edu/people/rts/publications.html)

Examples
---------

    require 'rubygems'
    require 'dm-core'
    require 'dm-migrations'
    require 'dm-is-temporal'
    
    DataMapper.setup(:default, "sqlite3::memory:")
        
    class MyModel
      include DataMapper::Resource
    
      property :id, Serial
      property :name, String
    
      is_temporal do
        property :foo, Integer
        property :bar, String
      end
    end
        
    DataMapper.auto_migrate!
    
    m = MyModel.create(:name => 'start', :foo => 1)
        
    m.foo
    #= 1
    m.name  
    #=> 'start'
    
    m.foo = 2
    
    m.name = 'hello'
    m.name  
    #=> 'hello'
    
    m.foo
    #= 2
    
    m.foo = 42
        
    old = DateTime.parse('-4712-01-01T00:00:00+00:00')
    m.at(old).foo
    #=> nil
    m.foo
    #=> 42
    
    m.update(:foo => 100, :name => 'goodbye')
    
    m.foo
    #=> 100
    m.name
    #=> 'goodbye'
    

Copyright
----------

Copyright © 2011 Joe Kutner. Released under the MIT License.

See LICENSE for details.