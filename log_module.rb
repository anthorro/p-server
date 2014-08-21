#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

module Logger
# logging module.
# when a log event occurs, check the log level, and depending on severity,write it to the output log file, or the DB, or both.
# perhaps also write it to the outpt terminal. Later. 

def initialize
    # In this module, since only one logger will be present, it's OK to create the global db handle needed. 
    # log levels set in constants.rb
    # EMERGENCY=0; ALERT=1; CRITICAL=2; ERROR=3   
    # WARNING=4; NOTICE=5; INFO=6; DEBUG=7
     begin      
     $logbuffer = {:emergency =>[],:alert =>[],:critical =>[],:all =>[]} #hash of short buffers to store recent errors in.  
     $stderr.print("\n- the Logger module initialized as mixin.")
     #make use of the db optional.  use if the Persist module is loaded. 
     @loghandle = self.respond_to?("dbhandle") ? dbhandle(SQLLOGACCOUNT,SQLLOGPASS,SQLDFLTDB) : nil # no args means use defaults from constants.  
     @logfile = File.new(LOGFILE,"a")
     @logfile.print("\n logger starting with loglevel #{$currentloglevel}") 
     @now = Time
     rescue StandardError
       $stderr.print("\n- the Logger module failed to initialize. #{$!}")
       raise #pass it on. For now. 
     end
     super # call super in case other Modules are also mixed in with initialization routines.
end

def logit(loglevel,msg='')
  #build a message, and filter by loglevel.
  #loglevel is required.  all others are optional. 
  # if the logit is called as a result of an Exception, it will log the exception. 
  begin
  category=subcat="default" #those could be set later with some logic. Or not!
  msg = strip(msg +':'+ $!.to_s)[0,254]
  node_class_method = String.new() << @now.now.to_s << ' ' << HOSTNAME 
  node_class_method += ':'  + strip($@[0].to_s) unless $@ == nil 
  
  # also add to the global logbuffers, for convenience.  
    $logbuffer[:all].shift while $logbuffer[:all].length > 9 #limit to last 9 messages
    $logbuffer[:all].push("loglevel #{loglevel} #{node_class_method} #{msg}")
   if (loglevel == EMERGENCY) #put that in the special buffer. 
      $logbuffer[:emergency].shift while $logbuffer[:emergency].length > 99 #limit to last 9 messages
      $logbuffer[:emergency].push("loglevel #{loglevel} #{node_class_method} #{msg}")
   end
  
   #if $currentloglevel is DEBUG, also write out to std.out
    $stderr.print("\n DEBUG:: "+node_class_method + msg) if $currentloglevel == DEBUG
    
  ## if the error is more serious  than the current log level, log the error to the DB and write it to a file.
  return unless loglevel <= $currentloglevel
  loginsert(loglevel,node_class_method,msg,category,subcat) if self.respond_to?("dbhandle")
  #and write to a file. 
  @logfile.print("\nloglevel #{loglevel} #{node_class_method} #{msg}") #didn't work?
  @logfile.flush
  
   
   rescue StandardError
      $stderr.print("\n ERROR IN LOGIT:: " + $!)
   end
end

def loginsert(loglevel,node_class_method,msg,cat="default",subcat="default")
  begin
  $stderr.print("\n loginsert running ")
  q="class_method='#{node_class_method}',log_level=#{loglevel.to_i},category='#{cat}',subcat='#{subcat}',message='#{msg}'" # the portion of sql after SET, use HOSTNAME as well. 
  dbinsert_delayed(@loghandle,"error_log",q)
  rescue StandardError
    #who logs the logger errors?
    $stderr.print("\n caught error in loginsert: #{$!}  ")
    $@.each{|k|$stderr.print("\n #{k}")}
  end
end

def Logger.close
  # close thlog DB handle and the log file handle
   @myloghandle.close if self.respond_to?("dbhandle")
   @logfile.close
end

def Logger.hello
   $stderr.print("\n Hello from the logger!")
end
 
end #end the Logger module

