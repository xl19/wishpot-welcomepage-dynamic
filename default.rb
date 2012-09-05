require 'sinatra'
#require 'sinatra/reloader' if development?
require 'sinatra/flash'
require 'haml'
require './lib/helper'
#require './lib/migrations'
require 'data_mapper'
require 'open-uri'
require 'json'
require 'aws/ses' #for sending mail for leads

#This long version is apparently required or the cookies get lost on heroku
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'venpop'

disable :protection #facebook requests fail this
enable :raise_errors #allow exceptional to catch our exceptions
set :haml, :format => :html5, :layout=>:layout

class WelcomePage
  include DataMapper::Resource
  property :page_id, String, :key=>true
  property :app_id, String, :key=>true
  property :page_name, String
  property :text, Text
  property :admin_id, String
  property :admin_email, String
  property :created_at, DateTime, :default=>lambda { |r, p| DateTime.now.new_offset(0) }
	has n, :collected_emails
  has n, :welcome_page_edits
end

class WelcomePageEdit
  include DataMapper::Resource
  property :edited_at, DateTime, :default=>lambda { |r, p| DateTime.now.new_offset(0) }
  property :user_id, String
  property :ip_address, String
  property :text, Text
  belongs_to :welcome_page, :key=>true
end

class CollectedEmail
	include DataMapper::Resource
	property :user_id, String
	property :email_address, String
  property :created_at, DateTime, :default=>lambda { |r, p| DateTime.now.new_offset(0) }
	property :details, Text
	belongs_to :welcome_page, :key=>true
end

configure do
  # Heroku has some valuable information in the environment variables.
  # DATABASE_URL is a complete URL for the Postgres database that Heroku
  # provides for you, something like: postgres://user:password@host/db, which
  # is what DM wants. This is also a convenient check wether we're in production
  # / not. "sqlite3:///#{Dir.pwd}/db/development.sqlite3"
  DataMapper.setup(:default, ( "postgres://todbvqgevikqfb:8m4A_i9G8xUorCRFuNPaVwGddr@ec2-107-22-161-45.compute-1.amazonaws.com/d5nudpe1f1kh36" || "postgres://postgres:wishpot123!@localhost/welcomepage_development" ))
  #DataMapper.setup(:default, (ENV["DATABASE_URL"] || "postgres://postgres:wishpot123!@localhost/welcomepage_development" ))
  #DataMapper.setup(:default, (ENV["HEROKU_POSTGRESQL_OLIVE_URL"] || "postgres://postgres:wishpot123!@localhost/welcomepage_development" ))
  DataMapper.finalize
  
  #Uncomment this anytime you want to run the migrations.  It's safe to re-run them.
  #require './lib/migrations'
  DataMapper.auto_upgrade!
  
  FB_CONFIG = YAML.load_file('config/facebook_apps.yml')
end

configure :production do
  require 'newrelic_rpm'
  require 'exceptional'
  use Rack::Exceptional, ' b4b310a81cc2b96c94d12c5a9077ab5c65cd8225'

  #So we can log in heroku: http://devcenter.heroku.com/articles/ruby#logging
  $stdout.sync = true
end

configure :development do
  DataMapper::Logger.new(STDOUT, :debug)
end


helpers do
  #Returns the current application in the config
  def current_app
    FacebookRequest.APPS_BY_ID[session[:app_id]]
  end
  
  #The session token is scoped to the app and page to make sure that sessions can't 
  #leak across those boundaries.  All app/page combos should feel distinct
  def session_access_token
   #p "GETTING: #{@app_id}_#{@page_id}"
   session["access_token_#{@app_id}_#{@page_id}"]
  end

  # Wanted this to look like a property (session_access_token=) but that didn't work
  # http://stackoverflow.com/questions/8619792/sinatra-helper-with-setter
  def set_session_access_token(v)
    #p "Setting: #{@app_id}_#{@page_id} access token to: #{v}"
    session["access_token_#{@app_id}_#{@page_id}"] = v
  end
  
  def get_content_for_welcome_page
    page = WelcomePage.get(@page_id, @app_id)
    @content = (page.nil?) ? '' : page.text
  end
  
  def given_email_cookie_name
    "venpop_email_#{@app_id}_#{@page_id}"
  end

  def testing_cookie_name
    "venpop_#{@app_id}_#{@page_id}"
  end

  def is_fully_authed?
    (!session_access_token.nil? && !@user_id.nil?)
  end

end

before do
   #grab tab id
   @page_id = nil
   @liked = false
   @admin = false
	 @given_email = false
	 

   # We check for the presence of the signature due to a potential existing Facebook session
   if(!params[:signed_request].nil? || (session[:page_id].nil? && !params[:cloned_signed_request].nil?))
     # We used to pass a secret key in here, but we can't cache the key in the session because
     # users may switch apps mid-session, which would mean we'd need to re-up the secret key, etc
     fb = FacebookRequest.decode(params[:signed_request] || params[:cloned_signed_request])
     unless(fb.nil?)
	   	 session[:page_id] = fb['page']['id']
		 p "FB_USER ID"
		 p fb['page']['id']
	     session[:liked] = fb['page']['liked']
		 p "FB_USER ID"
		 p fb['page']['liked']
	     session[:admin] = fb['page']['admin']
		 p "FB_USER ID"
		 p fb['page']['admin']
       session[:user_id] = fb['user_id']
	     p "FB_USER ID"
		 p fb['user_id']
	     #these values are only set if we didn't pass in an existing secret
	     session[:app_id] = fb['app_id'] if !fb['app_id'].nil?
	     session[:secret_key] = fb['secret_key'] if !fb['secret_key'].nil?
	  end
	 
	   @page_id = session[:page_id] 
	   @liked = session[:liked] 
	   @admin = session[:admin] 
	   @app_id = session[:app_id] 
	   @secret_key = session[:secret_key] 
	   @signed_request = params[:signed_request] || params[:cloned_signed_request]
	   @user_id = session[:user_id]
	
   # If we are outside of Facebook	
   else
   
	   @page_id = params[:fb_page_id]
	   @app_id = params[:fb_app_id]

   end
	   
   response.set_cookie(testing_cookie_name, {:value => '1'})

	 if(request.cookies[given_email_cookie_name])
	 		@given_email = true
	 		@just_given_email = (request['referrer'] == 'email')
	 end
end

after do
  #make sure we can set cookies in facebook in IE
  response.headers['P3P'] = 'CP="IDC DSP COR CURa ADMa OUR IND PHY ONL COM STA"'
end

post '/' do
	get_content_for_welcome_page
  haml :index
end

get '/' do
	get_content_for_welcome_page
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

#Redirects the user to auth.  Call this on expired sessions, or non-existent sessions.
get '/doauth' do
  if @app_id.nil?
    haml :reidentify_app if @app_id.nil?
  else
	  redirect "https://www.facebook.com/dialog/oauth?client_id=#{@app_id}&scope=email&redirect_uri=#{URI.escape(request.url.gsub(request.path, ''))}/post-oauth"
  end
end

get '/admin' do

	#make sure we have the admin's email address
	if !is_fully_authed?
	  redirect '/doauth'
	end
  
	return "Sorry, your session may have timed out.  Please go back to your fan page, and click 'edit' again" if @page_id.nil?
	
	page = WelcomePage.get(@page_id, @app_id)
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
  return "Sorry, your session may have timed out.  Please go back to your fan page, and click 'edit' again" unless is_fully_authed?
  pg = WelcomePage.first_or_create({:page_id=>@page_id.to_s, :app_id=>@app_id.to_s}, {:admin_id=>@user_id})
  previous_text = pg.text #store in case we want to keep it in an edit record
	pg.attributes = {:text => params['content']}
 	unless pg.save
		@err_msg = "Error: "
		pg.errors.each do |e|
       @err_msg << " #{e.to_s}"
    end
		@content = params['content']
	else
    last_edit = pg.welcome_page_edits.last

    #save the text to the db when a certain amount of time has passed, or if the user changed
    include_text = last_edit.nil? || last_edit.user_id != @user_id || last_edit.edited_at < DateTime.now - (1/24.0)
    
    edit = WelcomePageEdit.create(:welcome_page=>pg,:user_id=>@user_id, :ip_address=>request.ip, :text=>(include_text ? previous_text : nil))
  
		@status_msg = "Saved!"
	end
	@content = params['content']
	haml :edit
end

# This is the target for a user submitting an email address to the system
post '/email' do
	unless @page_id.nil?
		pg = WelcomePage.get(@page_id, @app_id)
		ce = CollectedEmail.create(:email_address=>(params[:email] || params[:email_address]))
		ce.user_id = params[:uid] if(params[:uid])
		details = Array.new
		params.each{|n,v| details << "#{n}: #{v}" if n != 'email' && n != 'uid' && n != 'isPost' && n != 'cloned_signed_request'}
		ce.details = details*', '
    pg.collected_emails << ce
		
	  unless ce.save
			flash[:error] = "Error: "
			ce.errors.each do |e|
        flash[:error] << " #{e.to_s}"
    	end
			@content = pg.text
			haml :index
		end
  else
    p "WARN: Posted to the e-mail handler, but looks like we have no session."
	end
	response.set_cookie(given_email_cookie_name, { :expires => Time.now+365*24*60*60, :value=>Time.now.to_s } )
  redirect '/?referrer=email'	
end

get '/download_emails' do
	if @admin and !@page_id.nil?
		content_type 'text/csv', :charset => 'utf-8'
		return "Email Address, Created Time, Details\n" + CollectedEmail.all(:conditions =>{:welcome_page_page_id=>@page_id, :welcome_page_app_id=>@app_id}, :fields=>[:email_address, :created_at, :details], :order=>[:created_at.asc]).collect{|e| "#{e.email_address},#{e.created_at},\"#{e.details}\"\n"}.to_s
	end
	'error, try signing in again.'
end

get '/admin_download_emails' do
	if FacebookRequest.user_is_app_admin(session_access_token, @app_id)
		content_type 'text/csv', :charset => 'utf-8'
		return "Email Address, Facebook Id, Facebook Page, Created At\n" + WelcomePage.all( :order=>[:created_at.asc]).collect{|e| "#{e.admin_email},#{e.admin_id},#{e.page_id},#{e.created_at}\n"}.to_s
	end
	"Error, try signing in again, or ensure you're an admin for app #{@app_id}"
end

get '/post-oauth' do
	begin
	  #p "going to request access token for app #{@app_id} on page #{@page_id} with the returned code: #{params[:code]}"
		set_session_access_token FacebookRequest.get_access_token(@app_id, @secret_key, params[:code], URI.escape(request.url.gsub(request.path, '').gsub('?'+request.query_string, ''))+"/post-oauth")
		@me = FacebookRequest.get_user(session_access_token)
		pg = WelcomePage.first_or_create({:page_id=>@page_id.to_s, :app_id=>@app_id})
    @fb_page = FacebookRequest.get_by_id(@page_id, session_access_token)
		
		is_new = pg.admin_id.nil? #keep track of whether or not this is a new welcome page, for CRM
		
		pg.attributes = {:admin_id => @me['id'], :admin_email=>@me['email']}
    pg.attributes = {:page_name=>@fb_page['name']} unless @fb_page.nil?

		pg.save
		
		if is_new
		  @email = @me['email']
  		@full_name = @me['first_name'] +' ' + @me['last_name']
  		
  		ses = AWS::SES::Base.new(
        :access_key_id     => 'AKIAIJRTFQDNNSDA233A', 
        :secret_access_key => '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'
      )
      
      #if we were using smtp, would be:
      #u: AKIAJT2WUBQJS37Z26KA
      #p: AgdMygbYNEX1k5IGpscvRlcq66xomMu4NJE6M2bBqrJR
      
      ses.send_email :to      => ['leads@venpop.com', 'ops@wishpot.com'],
                   :source    => '"Welcomepage Lead" <support@venpop.com>',
                   :subject   => "[Lead] New Welcome Page App User: #{@full_name} (#{@email})",
                   :text_body => haml(:email_new_admin, :layout=>false)
      
  		#Pony.mail(:to => 'sales@wishpot.com', :cc=>'tom@venpop.com', :from => 'ops@venpop.com', :subject => "[Lead] New Welcome Page App User: #{@full_name}", :body=>haml(:email_new_admin, :layout=>false))
  		#Pony.mail(:to => 'tom@lianza.org', :from => 'ops@venpop.com', :subject => "[Lead] New Welcome Page App User: #{@full_name}", :body=>haml(:email_new_admin, :layout=>false))
  	end
  	
		redirect '/admin'
	rescue
    p $!.backtrace
		"Error authenticating with facebook: #{$!}"
	end
end

get '/clear-email' do
  response.set_cookie(given_email_cookie_name, { :expires => Time.now-1} )
  "<script type='text/javascript'>history.go(-1);window.location.href='/';</script>"
end

