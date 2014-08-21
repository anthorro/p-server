#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

# a file for mixed in modules. 


#Module for HTTP protocol actions on a socket. 
module Cronodule

def cron()
  nap = 1.5 # the cron sleep time between (likely) runs, in seconds
  t = Time.new  
  was = {:year => t.year, :month => t.month, :day => t.day, :hour => t.hour, :minute => t.min, :second => t.sec}
  
  is = Hash.new
    #variables that can be reused for performance gains. 
    loop{
      now = Time.now
      is = {:year => now.year, :month => now.month, :day => now.day, :hour => now.hour, :minute => now.min, :second => now.sec}
      
      #$stderr.print("beep.")
      
      ##this is ugly but efficient. 
      # I could probably put the time compnents (day, minute, etc) in an array and iterate. or recurse. 
      if(is[:second] != was[:second])
         second(is[:second]) #run the second code. 
         was[:second] = is[:second] #reset the second. 
         if(is[:minute] != was[:minute])
           minute(is[:minute])
           was[:minute] = is[:minute] #reset the minute.
            if(is[:hour] != was[:hour])
              hour(is[:hour])
              was[:hour] = is[:hour] #reset the hour.
               if(is[:day] != was[:day])
                 day(is[:day])
                 was[:day] = is[:day] #reset the day.
                  if(is[:month] != was[:month])
                    month(is[:month])
                    was[:month] = is[:month] #reset the month.
                     if(is[:year] != was[:year])
                       minute(is[:year])
                       was[:year] = is[:year] #reset the year.
                     end #end years
                  end #end months
               end #end days
            end #end hours
         end #end minutes
      end #end the if seconds don't match
      
     Kernel.sleep(nap) #sleep for a given period  
     #turn the below on after integration and testing into the threads. 
    #$run ? Thread.pass : Thread.kill #sleep or suicide after processing  
    }
     #end the permanent  loop 
end    

def second(is)
  #run all this stuff when a second turns over. 
  begin
  rescue
    raise "cronicle error in the second method: " < $!
  end
end


def minute(is)
  #run all this stuff when a minute turns over.
  begin
   #$stderr.print("\n .a new minute")
  rescue
   raise "cronicle error in the minute method: " < $!
  end
end


def hour(is)
  #run all this stuff when an hour turns over. 
  begin
   $stderr.print("\n .a new hour")
  rescue
   raise "cronicle error in the hour method: " < $!
  end
end


def day(is)
  #run all this stuff when a day turns over. 
  begin
   $stderr.print("\n .a new day")
  rescue
   raise "cronicle error in the day method: " < $!
  end
end


def month(is)
  #run all this stuff when a month turns over. 
  begin
   $stderr.print("\n .a new month")
  rescue
   raise "cronicle error in the minute month: " < $!
  end
end


def year(is)
  #run all this stuff when a year turns over. 
  begin
   $stderr.print("\n .a new year")
  rescue
   raise "cronicle error in the minute year: " < $!
  end
end

  
def hello
	"Hello from Cronodule."
end

end #end the Cronodule module

