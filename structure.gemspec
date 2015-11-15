Gem::Specification.new do |s|
  s.name        = 'Structure'
  s.description = 'Organise ActiveRecord model into a pseduo graph structure'
  s.summary     = 'Ancestry allows the records of a ActiveRecord model to be organised in a tree structure, using a single, intuitively formatted database column. It exposes all the standard tree structure relations (ancestors, parent, root, children, siblings, descendants) and all of them can be fetched in a single sql query. Additional features are named_scopes, integrity checking, integrity restoration, arrangement of (sub)tree into hashes and different strategies for dealing with orphaned records.'

  s.version = '1.0.0'

  s.author   = 'Stefan Kroes'
  s.email    = ''
  s.homepage = 'http://github.com/stefankroes/ancestry'

  s.files = [
    'structure.gemspec', 
    'init.rb', 
    'install.rb', 
    'lib/ancestry.rb', 
    'lib/ancestry/has_ancestry.rb', 
    'lib/ancestry/exceptions.rb', 
    'lib/ancestry/class_methods.rb', 
    'lib/ancestry/instance_methods.rb', 
    'MIT-LICENSE', 
    'README.rdoc'
  ]
  
  s.add_dependency 'activerecord', '>= 4.2.0'
end
