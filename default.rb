require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'lib/helper'
require 'data_mapper'


class WelcomePage
  include DataMapper::Resource
  property :page_id, String, :key => true
  property :text, String
end

configure do
  # Heroku has some valuable information in the environment variables.
  # DATABASE_URL is a complete URL for the Postgres database that Heroku
  # provides for you, something like: postgres://user:password@host/db, which
  # is what DM wants. This is also a convenient check wether we're in production
  # / not.
  DataMapper.setup(:default, (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/db/development.sqlite3"))
  DataMapper.auto_upgrade!
end

before do
   #grab tab id
   @page_id = nil
   @liked = false
   @admin = false
   if(!params[:signed_request].nil?)
   	fb = FacebookRequest.decode(params[:signed_request], 'ecfa6c4aa238c9bf1d826d91316067aa')
   	@page_id = fb['page']['id']
    @liked = fb['page']['liked']
    @admin = fb['page']['admin']
   end
end

post '/' do
	@content = WelcomePage.get(@page_id).text
    haml :index
end

get '/' do
	@content = WelcomePage.get(@page_id).text
    haml :index
end

get '/admin' do
	#p "accessing admin: #{@admin}"
	@content = WelcomePage.get(@page_id).text
    haml :edit
end

post '/admin' do
	pg = WelcomePage.first_or_create({:page_id=>@page_id}, {:text => params['content']})
	pg.save
	#p "Should be saving [admin? #{@admin}] for page #{@page_id} and content: #{ params['content']}"
    redirect "/?signed_request=#{params[:signed_request]}"
end