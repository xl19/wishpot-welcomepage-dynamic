require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'lib/helper'
require 'data_mapper'
require 'open-uri'
require 'json'

enable :sessions
disable :protection #facebook requests fail this
set :haml, :format => :html5, :layout=>:layout

class WelcomePage
  include DataMapper::Resource
  property :page_id, String, :key=>true
  property :app_id, String
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

configure :production do
  require 'newrelic_rpm'
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
     # We used to pass a secret key in here, but we can't cache the key in the session because
     # users may switch apps mid-session, which would mean we'd need to re-up the secret key, etc
     fb = FacebookRequest.decode(params[:signed_request])
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

post '/image_upload' do
  @transloadit_api = '4cca35726f4c4cf593da639972ec3211'
  @transloadit_template = '8173f3a685e846be97b1714ea370caec'
  resp = params[:transloadit]
  #p @resp
  result = JSON.parse(resp)
  #p result
  @img_url = result['results'].first[1].first['url']
  @img_w = result['results'].first[1].first['meta']['width']
  @img_h = result['results'].first[1].first['meta']['height']
  haml :image_upload
end

get '/image_upload' do
  @transloadit_api = '4cca35726f4c4cf593da639972ec3211'
  @transloadit_template = '8173f3a685e846be97b1714ea370caec'
  haml :image_upload
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
	# start back-filling old pages with their app id's
	pg.attributes = {:app_id => @app_id} if pg.app_id.nil?
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

get '/admin_download_emails' do
	if FacebookRequest.user_is_app_admin(session['access_token'])
		content_type 'text/csv', :charset => 'utf-8'
		return "Email Address, Facebook Id, Facebook Page, Created At\n" + WelcomePage.all( :order=>[:created_at.asc]).collect{|e| "#{e.admin_email},#{e.admin_id},#{e.page_id},#{e.created_at}\n"}.to_s
	end
	'error, try signing in again.'
end

get '/post-oauth' do
	begin
		session['access_token'] = FacebookRequest.get_access_token(@app_id, @secret_key, params[:code], URI.escape(request.url.gsub(request.path, '').gsub('?'+request.query_string, ''))+"/post-oauth")
		me = FacebookRequest.get_user(session['access_token'])
		pg = WelcomePage.first_or_create({:page_id=>@page_id.to_s})
		pg.attributes = {:admin_id => me['id'], :admin_email=>me['email']}
		pg.save
		redirect '/admin'
	rescue
		#p token_url
		"Error authenticating with facebook: #{$!}"
	end
end

