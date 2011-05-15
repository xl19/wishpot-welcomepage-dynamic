require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'lib/helper'
require 'data_mapper'
require 'open-uri'

enable :sessions

class WelcomePage
  include DataMapper::Resource
  property :page_id, String, :key => true
  property :text, Text
  property :admin_id, String
  property :admin_email, String
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

	 if development?
   	@app_id = 109846262436497
   	@secret_key = '4d141f0649456fc8695762b80fd016ac'
	 else
   	@app_id = 210073625689149
   	@secret_key = 'ecfa6c4aa238c9bf1d826d91316067aa'
   end
	 
   if(!params[:signed_request].nil?)
     fb = FacebookRequest.decode(params[:signed_request], @secret_key)
     if(!fb.nil?)
	   	 session[:page_id] = fb['page']['id']
	     session[:liked] = fb['page']['liked']
	     session[:admin] = fb['page']['admin']
	  end
   end
   @page_id = session[:page_id]
   @liked = session[:liked]
   @admin = session[:admin]
end

post '/' do
	page = WelcomePage.get(@page_id) 
	@content = (page.nil?) ? '' : page.text
  haml :index
end

get '/' do
	page = WelcomePage.get(@page_id)
  @content = (page.nil?) ? '' : page.text
	haml :index
end

get '/admin' do
	#make sure we have the admin's email address
	if session['access_token'].nil?
		redirect "https://www.facebook.com/dialog/oauth?client_id=#{@app_id}&redirect_uri=#{URI.escape(request.url.gsub(request.path, ''))}/post-oauth&scope=email" 
	end
	page = WelcomePage.get(@page_id)
  @content = (page.nil?) ? "This is your new welcome page - delete me and edit away! \n\n If you're comfortable writing HTML, check out the 'HTML' button in the menu above." : page.text
  haml :edit
end

post '/admin' do
	pg = WelcomePage.first_or_create({:page_id=>@page_id.to_s}, {:text => params['content']})
	pg.attributes = {:text => params['content']}
 	unless pg.save
		@err_msg = "Error: "
		pg.errors.each do |e|
       @err_msg << " #{e.to_s}"
    end
		@content = params['content']
	else
		@status_msg = "Saved!"
	end
	@content = params['content']
	haml :edit
end

get '/post-oauth' do
	#grab the access token
	OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
	token_url = "https://graph.facebook.com/oauth/access_token?client_id=#{@app_id}&redirect_uri=#{URI.escape(request.url.gsub(request.path, '').gsub('?'+request.query_string, ''))}/post-oauth&client_secret=#{@secret_key}&code=#{params[:code]}"
	begin
		resp_parts = open(token_url).string.split('&')
		session['access_token'] = resp_parts[0].gsub('access_token=', '')
		#grab the user and update the db
		me = JSON.parse open("https://graph.facebook.com/me?access_token=#{URI.escape(session['access_token'])}").string
		pg = WelcomePage.first_or_create({:page_id=>@page_id.to_s})
		pg.attributes = {:admin_id => me['id'], :admin_email=>me['email']}
		pg.save
		redirect '/admin'
	rescue
		p token_url
		"Error authenticating with facebook: #{$!}"
	end
end

