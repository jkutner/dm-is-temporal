require 'dm-core'
require 'dm-is-temporal/is/temporal'

# Include the plugin in Resource
module DataMapper
  module Model
    include DataMapper::Is::Temporal
  end
end