require "sinatra/base" 
# require "sinatra/sugar"               
require 'json'

class RESTInterface < Sinatra::Base
  
  post '/instance' do
    content_type :json 
    {id: settings.simple_cloud.create(params[:image], params[:memory].to_i)}.to_json
  end
  
  delete '/instance/:instance_id' do
    content_type :json 
    settings.simple_cloud.destroy(params[:instance_id])
    {status: 1}.to_json
  end
  
  get '/instances' do
    settings.simple_cloud.instances.to_json
  end
  
  get '/images' do
    settings.simple_cloud.images.keys.to_json
  end
  
  
end