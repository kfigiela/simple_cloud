require_relative 'simple_cloud'
require_relative 'webservice'
require 'yaml'

config = YAML.load File.read(ARGV[0])
cloud = SimpleCloud.new config
RESTInterface.set :simple_cloud, cloud
RESTInterface.run!
