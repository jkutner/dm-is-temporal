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
    
    m = MyModel.create(:name => 'start', :foo => 42)
        
    m.foo
    #= 42
    m.name  
    #=> 'start'

    old = DateTime.parse('-4712-01-01T00:00:00+00:00')
    now = DateTime.now

    m.at(old).foo
    #=> nil

    m.at(now).foo
    #=> 42

    m.foo = 1024
    m.foo
    #=> 1024

    m.at(old).foo
    #=> nil
    m.at(now).foo
    #=> 42

    # .name isn't temporal
    m.at(old).name
    #=> 'start'
    m.at(now).name
    #=> 'start'


How it works
-------------
Temporal patterns differ from versioning patterns (such as [dm-is-versioned](https://github.com/datamapper/dm-is-versioned))
in that every version of the temporal properties is a peer (even the most recent).  Accessing temporal properties without the `at(time)` method
is just a convinience for `at(DateTime.now)`.

When you use the `is_temporal` form, the plugin will dynamically create a temporal version table.  In the example above,
these two tables would be created:

    # db.my_models table
  ---------------------------------------------
  | id | name                                 |
  ---------------------------------------------
  | 1  | 'start'                              |


  # db.my_model_temporal_versions table
  ---------------------------------------------------------------------------------------
  | id | foo               | bar                       | updated_at |
  ---------------------------------------------------------------------------------------
  | 1  | '42'               | null                     | DateTime   |
  | 1  | '1024'             | null                     | DateTime   |
  | 1  | '1024'             | null                     | DateTime   |

Thanks
------
Thanks to the [dm-is-versioned](https://github.com/datamapper/dm-is-versioned) folks!  I based a lot of my infrastructure
on that project.

TODO
------

+  Temporal Property pattern (i.e. multiple independent temporal properties per class)
+  Bi-temporality


Copyright
----------

Copyright © 2011 Joe Kutner. Released under the MIT License.

See LICENSE for details.