require 'base64'
require 'openssl'
require 'active_support'
require 'net/https'

class FacebookRequest
  
  #A hash of the apps by id, for fast lookups
  def self.APPS_BY_ID
    @@applications ||= FB_CONFIG.inject({}) { |h,(k,v)| h[v['id']] = v; h }
  end
 
  #In addition to decoding the signed request, this method is also responsible for figuring out what 
  #application we are on, and will return a secret_key and app_id as part of the data returned if you 
  #*do not* pass in a secret.  If you do pass in a secret, will simply validate against it
  def self.decode (signed_request, secret=nil)
   	#decode data
	  encoded_sig, payload = signed_request.split('.')
	  return nil if encoded_sig.nil?
	  sig = str_to_hex(base64_url_decode(encoded_sig))
	  data = ActiveSupport::JSON.decode base64_url_decode(payload)
	
	  #unknown algorightm
	  return false if data['algorithm'].to_s.upcase != 'HMAC-SHA256'
	  
	  #check sig if we already have one
	  return check_sig(secret, payload, sig) ? data : nil unless secret.nil?
	  
	  #if we don't have one, iterate through the possibilities
	  FB_CONFIG.each_value{|app|
	    if check_sig(app['secret'], payload, sig)
	      data['app_id'] = app['id']
	      data['secret_key'] = app['secret']
	      return data
      end
	  }
	  
	  #we could not validate the signature against any known application
	  return nil
  end
  
  #Currently this is just a hard-coded list of facebook ids
  def self.user_is_app_admin(access_token_param, app_id)
    u = self.get_user(access_token_param)
    #is_admin = self.get_fql("SELECT developer_id FROM developer WHERE application_id='#{app_id}' AND developer_id='#{u['id']}'")
    ['4810243'].include?(u['id'])
  end
  
  #If you leave the auth_code nil, grabs it for the app, not a user
  def self.get_access_token(app_id, secret, auth_code=nil, redirect_uri=nil)
    token_url = "https://graph.facebook.com/oauth/access_token?client_id=#{app_id}&client_secret=#{secret}"
    token_url += "&code=#{auth_code}" unless auth_code.nil?
    token_url += "&redirect_uri=#{redirect_uri}" unless redirect_uri.nil?
    #p token_url
    return open(token_url).string
  end
  
  def self.get_user(access_token_param)
    return JSON.parse open("https://graph.facebook.com/me?#{URI.escape(access_token_param)}").string
  end
  
  def self.get_fql(q)
    #p "Running query: https://graph.facebook.com/fql?q=#{URI.escape(q)}"
    return JSON.parse open("https://graph.facebook.com/fql?q=#{URI.escape(q)}").string
  end
  
  
  private
  
    def self.check_sig(secret, payload, given_sig)
      raise ArgumentError, "Secret cannot be nil", caller if secret.nil?
      raise ArgumentError, "Signature cannot be nil", caller if given_sig.nil?
      
      return OpenSSL::HMAC.hexdigest('sha256', secret, payload) == given_sig
    end
  
    def self.base64_url_decode str
      encoded_str = str.gsub('-','+').gsub('_','/')
      encoded_str += '=' while !(encoded_str.size % 4).zero?
      Base64.decode64(encoded_str)
    end

    def self.str_to_hex s
      (0..(s.size-1)).to_a.map do |i|
        number = s[i].to_s(16)
        (s[i] < 16) ? ('0' + number) : number
      end.join
    end

end

# Patch to make sure we load the certificates for facebook
# http://jimneath.org/2011/10/19/ruby-ssl-certificate-verify-failed.html
module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=
    
    def use_ssl=(flag)
      self.ca_file = 'lib/ca-bundle.crt'
      self.verify_mode = OpenSSL::SSL::VERIFY_PEER
      self.original_use_ssl = flag
    end
  end
end
