dm-is-temporal
==================================

DataMapper plugin implementing temporal patterns on DataMapper models.

These patterns are based on research by Martin Fowler, Richard Snodgrass and others.  For more information follow these links:

+  [Temporal Patterns](http://martinfowler.com/eaaDev/timeNarrative.html)
+  [Developing Time-Oriented Database Applications in SQL](http://www.cs.arizona.edu/people/rts/publications.html)

Examples
---------

So lets assume you have a simple class. The plugin will automatically create some auxillary tables when you auto_migrate.

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

You can create, modify and access it as normal:

    m = MyModel.create(:name => 'start', :foo => 42)

    m.bar = 'hello'
    m.foo              #= 42
    m.name             #=> 'start'

Or you can access it at different time (future or past):

    old = DateTime.parse('-4712-01-01T00:00:00+00:00')
    now = DateTime.now

    m.at(old).foo         #=> nil
    m.at(now).foo         #=> 42

But it really gets interesting when you modify it `at` different `DateTime`s

    oldish = DateTime.parse('-4712-01-01T00:00:00+00:00')
    nowish = DateTime.parse('2011-03-01T00:00:00+00:00')
    future = DateTime.parse('4712-01-01T00:00:00+00:00')

    m.at(oldish).foo = 1

    m.at(oldish).foo       #=> 1
    m.at(nowish).foo       #=> 42
    m.at(future).foo       #=> 42

    m.at(nowish).foo = 1024

    m.at(oldish).foo        #=> 1
    m.at(nowish).foo        #=> 1024
    m.at(future).foo        #=> 1024

    m.at(future).foo = 3

    m.at(oldish).foo        #=> 1
    m.at(nowish).foo        #=> 1024
    m.at(future).foo        #=> 3

Remember that properties outside of the `is_temporal` block are not versioned.  But you can read and write them though the `at(time)` method if you want:

    # .name isn't temporal
    m.at(old).name
    #=> 'start'
    m.at(now).name
    #=> 'start'

If you try to set a value at the same time as one you already set, it will overwrite the previous value (like non-temporal models).  In future versions of dm-is-temporal you will be able to configure if this works or causes an error.

    m.at(nowish).foo = 11
    m.at(nowish).foo         #=> 11

    m.at(nowish).foo = 22
    m.at(nowish).foo         #=> 22


How it works
-------------
Temporal patterns differ from versioning patterns (such as [dm-is-versioned](https://github.com/datamapper/dm-is-versioned))
in that every version of the temporal properties is a peer (even the most recent).  Accessing temporal properties without the `at(time)` method
is just a convinience for `at(DateTime.now)`.

In addition, you have the ability inject versions at previous time-states (modifying history).

When you use the `is_temporal` form, the plugin will dynamically create a temporal version table.  In the example above,
these two tables would be created:

    # db.my_models table
    ---------------------------------------------
    | id | name                                 |
    ---------------------------------------------
    | 1  | 'start'                              |


    # db.my_model_temporal_versions table
    -----------------------------------------------------------------------
    | id | foo          | bar            | updated_at     | my_model_id   |
    -----------------------------------------------------------------------
    | 1  | '42'         | null           | DateTime       | 1             |
    | 2  | '1024'       | null           | DateTime       | 1             |
    | 3  | '1024'       | 'hello'        | DateTime       | 1             |

Thanks
------
Thanks to the [dm-is-versioned](https://github.com/datamapper/dm-is-versioned) folks!  I based a lot of my infrastructure
on that project.

TODO
------

+  MyClass.update (update all records for a model) doesn't work
+  Temporal Associations
+  Temporal Property pattern (i.e. multiple independent temporal properties per class)
+  Bi-temporality
+  Add a config flag that enables an error to be raised when attempting to rewrite existing versions


Copyright
----------

Copyright © 2011 Joe Kutner. Released under the MIT License.

See LICENSE for details.