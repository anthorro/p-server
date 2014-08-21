#Copyright (C) 2010-2012  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

module Honeydoo
# Honeydoo module.
# Processes Posts etc of to-do lists,  grocery lists, etc, and sends them to 
# a recipient via SMS or MMS.
require 'digest/md5'
require 'cgi'
require 'net/http'
require 'uri'

def initialize
     begin      
     $stderr.print("\n- the Honeydoo module initialized as mixin.")
     rescue StandardError
       $stderr.print("\n- the Honeydoo module failed to initialize. #{$!}")
       raise #pass it on. For now. 
     end
     super # call super in case other Modules are also mixed in with initialization routines.
end

def Honeydoo.hello
   $stderr.print("\n Hello from the Honeydoo!")
end
 
def auth_honeydo
  # print or log all the http params of the call in so we can figure out what to do with it. 
  logit($currentloglevel,"logging frm auth_honey_do")
  logit($currentloglevel," reqinfo: #{@reqInfo}")
  logit($currentloglevel," @reqHeaders: #{@reqHeaders}")
  logit($currentloglevel," @posthash: #@posthash}")
  $stderr << "\n auth_honeydo complete. "
  "return success."
end # end Auth honeydo. 

   
def honeydooit
  # process the post and perform the actions. 
  
  $stderr << "\n caught this posthash: " << @posthash.inspect
  
  @posthash.each{|k,v|@posthash[k]=CGI::unescape(v)}
  
  selfsend = @posthash.delete('selfsend')
  $stderr << "\n selfsend was " << selfsend.to_s
  @posthash.delete_if{|k,v| v == "..." }
  message = "Hi honey! would you get this stuff for me PLEASE???\n "
  @posthash.each{|k,v|message << "\n #{v}"}
  stuff = {:client_id  => 837,
  :token =>  "5cc0c30ec718938724233095f13806fe",
  :campaignIDs=>[18526,18527] }
  
  
  to = "2063695205"
  from = "2069157629"
  url = "https://api.mogreet.com/moms/transaction.send?client_id=#{stuff[:client_id]}&token=#{stuff[:token]}&campaign_id=18527&to=#{to}&message=#{CGI::escape(message)}&subject=#{CGI::escape("incoming honeydo list!")}"
  receipturl = "https://api.mogreet.com/moms/transaction.send?client_id=#{stuff[:client_id]}&token=#{stuff[:token]}&campaign_id=18527&to=#{from}&subject=#{CGI::escape("honeydo list receipt")}&message=#{CGI::escape("you sent this to your honey!::\n"+message)}"

  #uri = URI(url)
  $stderr << "\n \n gonna send this url: " << url
  $stderr << `curl -k "#{url}"`
  # was the box clicked to self send?
  $stderr <<  `curl -k "#{receipturl}"` if selfsend.eql?("on")
  

  return "sent this message to your honey:  \n\n #{message}"
  #return "<br> caught the action: " << @method << " " << @words.to_s << "<br> posthash is " << @posthash.inspect
end 
 
   # like a redirector, this class takes the words in and makes decisions about what logic to run to create the response.
  # this is the main logic branch for handling different HTML requests. 
def earl # Earl..earl...-URL, get it??? BigEarl is the AI with the BPM on Soma-FM. 
      
    begin
     body = String.new
          
     case @words[1]
      
     when nil
       url = PWEBROOT+'index.html'
       #logit(DEBUG,"no url, default to index.html")
       body <<  wrapreadfile(@mchandle,url)
    
    when 'honeydoo'
      body << honeydooit
      
    when 'auth_honeydo'
      body << auth_honeydo
      
     when 'file','webroot'
       ## check the memcached first, then read a file from disk, from the webroot, also store back to memcached. 
       url = PWEBROOT+@words[-(@words.length-2),@words.length-2].join('/')
       body <<  wrapreadfile(@mchandle,url)
          
     when 'cache','xml','html','text','page','css','js'
     # get the page named from the cache, or the backing db store if expired.
         uri = @words.join('/')  
         $stderr.print("\n\n earl: looking for this uri: " + uri)
         body << getpage(uri,"html")
          
     else
       url = PWEBROOT+@words[-(@words.length-1),@words.length-1].join('/')
       $stderr << "\n looking for file " << url
       body <<  wrapreadfile(@mchandle,url)
      # raise Error404.new()
       
     end #end words case
     
      return(body) #always return a body.  
    end
  end # end earl
  
  def getpage(uri="index.html", type="html")
    # convenience method for getting html, css, etc etc out of the DB, not filesystem, Built on top of the persist module wrap_get 
    uri = '/' + uri unless uri[0]==47 #append a '/' if one is missing. # all uri's must be absolute...
    result = wrapget(@mchandle,@mydevhandle,"text_stash","val","type='#{type}' AND uri='#{uri}' LIMIT 1")
    raise Error404.new("page not found in cache or db.") unless (result.class == Array && result.length >0)
    return result[0]['val'].to_s #just the val element.                        
  end
  
end #end the Honeydoo module