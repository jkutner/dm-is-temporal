begin
  gem 'jeweler', '~> 1.5.2'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'dm-is-temporal'
    gem.version     = '0.7.0'
    gem.summary     = 'DataMapper plugin implementing temporal patterns'
    gem.description = gem.summary
    gem.email       = 'jpkutner [a] gmail [d] com'
    gem.homepage    = 'http://github.com/jkutner/%s' % gem.name
    gem.authors     = [ 'Joe Kutner' ]
    gem.files =  FileList["[A-Z]*", "{lib,spec}/**/*"]
    
    #gem.has_rdoc    = 'yard'
    #gem.rubyforge_project = 'datamapper'
  end

  Jeweler::GemcutterTasks.new

  FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end
