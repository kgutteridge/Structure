require File.join(File.expand_path(File.dirname(__FILE__)), 'structure/class_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'structure/instance_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'structure/exceptions')
require File.join(File.expand_path(File.dirname(__FILE__)), 'structure/has_structure')

module Structure
  STRUCTURE_PATTERN = /\A[0-9]+(\/[0-9]+)*(,[0-9]+(\/[0-9]+)*)*\Z/
end