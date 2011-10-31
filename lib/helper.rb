require 'base64'
require 'openssl'
require 'active_support'

class FacebookRequest
  
  #A hash of the apps by id, for fast lookups
  def self.APPS_BY_ID
    @@applications ||= FB_CONFIG.inject({}) { |h,(k,v)| h[v['id']] = v; h }
  end
 
  #In addition to decoding the signed request, this method is also responsible for figuring out what 
  #application we are on, and will return a secret_key and app_id as part of the data returned if you 
  #*do not* pass in a secret.  If you do pass in a secret, will simply validate against it
  def self.decode (signed_request, secret)
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
