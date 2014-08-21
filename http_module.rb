# copyright 2008/2009 Anthony Rossano anthor@mesmer.com
#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

# the Phttp mixins for processing a GETS and PUTS. 
# see the 'responsebody() @method' for the logic
# where the request is really processed. 



## add HTTP errors here
class HttpError < RuntimeError
  attr_reader :headers, :body
end  

class Error501 < HttpError
  def initialize()
    @headers = 'HTTP/1.1 501 BAD-REQUEST' + NEWLINE + 'Content-Type: text/html'
    @body = "<HTML><BODY>Request Type Not Implemented.  P-server supports Post, GET, HEAD, you sent #{@method} </BODY></HTML>"
  end
end

class Error404 < HttpError
  def initialize(info="")
    @headers = 'HTTP/1.1 404 NOT-FOUND' +  NEWLINE  + 'Content-Type: text/html'
    @body = "<HTML><BODY>YIPPEEE!  Bad request, URL not found. (#{info})</BODY></HTML>"
  end
end

class Error204 < HttpError
  def initialize()
    @headers = 'HTTP/1.1 204 NO CONTENT' +  NEWLINE + 'Content-Type: text/html'
    @body = String.new() #Need a body, even if it's blank.  And it has to be blank for Error204.
  end
 
end



#Module for HTTP protocol actions on a socket. 
module Phttp

  
def initialize
  # initialize is called by the including class if it uses the keyword 'super'  in it's initialize. 
  $stderr.print("\n- module Phttp initialized as mixin.")
  @reqHeaders = Hash.new() #a hash of arrays of values from header - GET string, posts, etc. 
  @reqInfo = Array.new() # get all the info from the socket, like IP address, etc. 
  @responseHeaders = Array.new # build up the response headers
  @responseBody = String.new # build up the respone body (to calculate content length)
  @postdata = String.new()
  @posthash = Hash.new() # key/value hash made of the postdata 
  super # call super in case other Modules are also mixed in with initialization routines. 
end
  
def process(tsock)
    begin
    line = String.new() #for performance allocate a line string.
    lp = Array.new() #for performance, the split line
    @reqInfo=tsock.addr 

    ##clear out the shared instance variables.  
    @reqHeaders.clear
    @reqInfo.clear
    @responseHeaders.clear
    @posthash.clear
    @responseBody=''; @postdata='';
    
    #the first line determines the @method (GET, POST, etc) #this should be checked for buffer overflow... 
    lp = tsock.gets.chop.split(' ') #read the first line (allow for multiple spaces as delimiters?)
    @method,@url,@version = lp[0],lp[1],lp[2]
    @words = @url ? @url.split('/') : "no url available" 
    
    #read the remainder of the header.
    while true
          line = tsock.gets.chomp #read a line
          break if (!line | line.empty? | (line.length > (5*1024))) # end if out of info on the socket read, or too big. 
          lp = line.split(':') #each line represents an input parameter list in the form:  ParamName: val1,val2,val3
          @reqHeaders.store(lp[0],lp[1].to_s.split(','))
    end #end the while - all request headers read now.
          
    # throw any errors.....
    raise Error501.new() unless (@method == 'GET' || @method == 'POST' || @method == 'HEAD' && lp.length >=3 )
    
    #write the default success headers. 
    @responseHeaders.push('HTTP/1.1 200 OK' + NEWLINE + 'Content-Type: text/html') 
        
        # if there is a POST, and a content length, it can now read the content. 
          if(@method=='POST' && @reqHeaders.include?('Content-Length')) #is it a POST? with length?
            tsock.read(@reqHeaders['Content-Length'].to_s.to_i,@postdata)
            @postdata = URI.unescape(@postdata)
            #make a hash of any post field pairs. 
            @postdata.split('&').each{|i| j=i.split('='); @posthash[j[0]] = j[1] }
          end #end if it's a post

          # if the form is multipart, we could read the boundary:
          # Content-Type: multipart/form-data; boundary=---------------------------166255952535010552132159384
          #to divide up the content. 
          
        # build up the @responseBody instance variable
        @responseBody = yield
        raise Error204.new() unless (@responseBody!=nil &&  @responseBody.to_s.length!=0)
    
  
  rescue HttpError => e #all http exceptions descend from this base class. So they all match... 
     @responseHeaders.clear #drop whatever was in there, we don't know the state...
     @responseHeaders.push(e.headers)
     @responseBody = e.body
            
  rescue #everything else
      @responseHeaders.clear #drop whatever was in there, we don't know the state...
      @responseHeaders.push('HTTP/1.1 500 SERVER ERROR' + NEWLINE + 'Content-Type: text/html')
      @responseBody = '<HTML><BODY>Got DAMN! Server Error! Total Pimpin\' BREAKDOWN!  </BODY></HTML>'
      logit(CRITICAL,"http_module 500 error")
         
  ensure  
    #add the rest of the header info... 
    @responseHeaders.push('Connection: close')  #don't yet support persistent connections 
    @responseHeaders.push('Server: p-server 1.0a')
    @responseHeaders.push('Host: ' << HOSTNAME +  ':' + CONNECTIONPORT.to_s)
    @responseHeaders.push('Content-Length:' <<  @responseBody.length.to_s)  
    @responseHeaders.length.times{tsock.puts(@responseHeaders.shift + NEWLINE)} 
    tsock.puts NEWLINE  #Absolutely required, Headers must end with blank line.
    tsock.puts @responseBody
  end
end    
  
  
  
def hello
	"<br>wassup.I am an object of class: #{self.class}"
end

end #end the pimpHttp module
