require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'lib/helper'
require 'data_mapper'
require 'open-uri'

enable :sessions
set :haml, :format => :html5, :layout=>:layout

class WelcomePage
  include DataMapper::Resource
  property :page_id, String, :key=>true
  property :text, Text
  property :admin_id, String
  property :admin_email, String
  property :created_at, DateTime, :default=>DateTime.now.new_offset(0)
	has n, :collected_emails
end

class CollectedEmail
	include DataMapper::Resource
	property :user_id, String
	property :email_address, String, :key=>true
  property :created_at, DateTime, :default=>DateTime.now.new_offset(0)	
	property :details, Text
	belongs_to :welcome_page, :key=>true
end

configure do
  # Heroku has some valuable information in the environment variables.
  # DATABASE_URL is a complete URL for the Postgres database that Heroku
  # provides for you, something like: postgres://user:password@host/db, which
  # is what DM wants. This is also a convenient check wether we're in production
  # / not.
  DataMapper.setup(:default, (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/db/development.sqlite3"))
  DataMapper.auto_upgrade!
  FB_CONFIG = YAML.load_file('config/facebook_apps.yml')
end

#Returns the current application in the config
def current_app
  FacebookRequest.APPS_BY_ID[session[:app_id]]
end

before do
   #grab tab id
   @page_id = nil
   @liked = false
   @admin = false
	 @given_email = false
	 
   if(!params[:signed_request].nil?)
     fb = FacebookRequest.decode(params[:signed_request], session[:secret_key])
     unless(fb.nil?)
	   	 session[:page_id] = fb['page']['id']
	     session[:liked] = fb['page']['liked']
	     session[:admin] = fb['page']['admin']
	     #these values are only set if we didn't pass in an existing secret
	     session[:app_id] = fb['app_id'] if !fb['app_id'].nil?
	     session[:secret_key] = fb['secret_key'] if !fb['secret_key'].nil?
	  end
   end

   @page_id = session[:page_id]
   @liked = session[:liked]
   @admin = session[:admin]
   @app_id = session[:app_id]
   @secret_key = session[:secret_key]

	 if(request.cookies["venpop_email_#{@page_id}"])
	 		@given_email = true
	 end
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
	
	return "Sorry, your session may have timed out.  Please go back to your fan page, and click 'edit' again" if @page_id.nil?
	
	page = WelcomePage.get(@page_id)
	@email_count = 0
  if !page.nil?
		@content = page.text
		@email_count = page.collected_emails.count
	end

	if (@content.nil? or @content.length == 0) and !current_app['default'].nil?
	  @content = IO.read("views/app_templates/#{current_app['default']}")
  end
	
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

# This is the target for a user submitting an email address to the system
post '/email' do
	unless @page_id.nil?
		pg = WelcomePage.get(@page_id)
		ce = CollectedEmail.first_or_create(:welcome_page=>pg, :email_address=>(params[:email] || params[:email_address]) )
		ce.user_id = params[:uid] if(params[:uid])
		details = Array.new
		params.each{|n,v| details << "#{n}: #{v}" if n != 'email' && n != 'uid'}
		ce.details = details*', '
		
	  unless ce.save
			@err_msg = "Error: "
			ce.errors.each do |e|
       @err_msg << " #{e.to_s}"
    	end
			@content = pg.text
			haml :index
		end
	end
	response.set_cookie("venpop_email_#{@page_id}", { :expires => Time.now+365*24*60*60 } )
  redirect '/'	
end

get '/download_emails' do
	if @admin and !@page_id.nil?
		content_type 'text/csv', :charset => 'utf-8'
		return "Email Address, Created Time, Details\n" + CollectedEmail.all(:welcome_page_page_id=>@page_id, :order=>[:created_at.asc]).collect{|e| "#{e.email_address},#{e.created_at},\"#{e.details}\"\n"}.to_s
	end
	'error, try signing in again.'
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
		#p token_url
		"Error authenticating with facebook: #{$!}"
	end
end

