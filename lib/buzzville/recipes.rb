# can : 
# require 'buzzville/recipes' or 
# require 'buzzville/recipes/data'

require 'capistrano'
require 'capistrano/cli'

@@cap_config = Capistrano::Configuration.respond_to?(:instance) ? 
  Capistrano::Configuration.instance(:must_exist) :
  Capistrano.configuration(:must_exist)
  
#Dir.glob(File.join(File.dirname(__FILE__), '/recipes/*.rb')).each { |f| load f }
Dir.chdir(File.dirname(__FILE__)+'/..') { Dir['buzzville/recipes/*'] }.each {|f| load f }

