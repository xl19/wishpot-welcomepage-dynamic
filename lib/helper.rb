require 'base64'
require 'openssl'
require 'active_support'

class FacebookRequest
 
  def self.decode (signed_request, secret)
   		#decode data
	  encoded_sig, payload = signed_request.split('.')
	  sig = str_to_hex(base64_url_decode(encoded_sig))
	  data = ActiveSupport::JSON.decode base64_url_decode(payload)
	
	  #unknown algorightm
	  return false if data['algorithm'].to_s.upcase != 'HMAC-SHA256'
	    
	  #check sig
	  expected_sig = OpenSSL::HMAC.hexdigest('sha256', secret, payload)
	  return false if expected_sig != sig
	
	  return data
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