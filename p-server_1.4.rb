#!/usr/bin/ruby
#p-server:: pimpathon server v.3, Mogreet edition.
#copyright:: 2008 anthor@mesmer.com
#author:: Anthony Rossano, anthor@mesmer.com 
#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.#
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#  
  

BEGIN{
  #init code
  $stderr.print("\n launch p-server... get the server running. ")
  require 'socket'
  require 'thread'
  require 'URI'
  load 'constants.rb' # load app constants
  # Note: Sauce Server must be run setiuid root to bind to ports below 1000
  $console = TCPServer.open(CONSOLEPORT) #listen for console commands
  $stderr.print("\n $console is class: #{$console.class}")
  $connection = TCPServer.open(CONNECTIONPORT)  #listen for connections to process
  $timer = Time.now()
  $run = true #a flag for the kill switch  
}
END{
  #exit code
  $connection.close
  $stderr.print("\n ending\n")
}


class Consumer
  # Main processing thread to handle all http requests. 
  
  ### Put API module/class here. 
  
  
  require 'http_module.rb' #load the http module file
  include Phttp #include the http methods.
  
  require 'log_module.rb' # we might want this in a separate thread eventually, just to be really cool. 
  include Logger  #mix in the Logger module to give this thread access to the error logger.
  # persist is already required by pii... so it shouldl not load twice. 
  require 'persist_module.rb'
  include Persist  #mix in the Persist module to give this thread access to the memcached and mysql
 
  
  def  initialize()
  # Consumer is a worker bee to handle a request. 
  # the parent thread (p-server) has the producer/consumer queue and @threads, etc. 
  
    # Don't want the consumers to starve the producer.
    Thread.current.priority = -1
     
    begin
      @age = Time.now()
      @iterations = 0
      @id = self.object_id #now get this from the cthreads queue or something. 
      @tsock = nil #placeholder for the socket.
      
      # make default persistent connections
      # don't know if that's too easy.... 
      @mydevhandle = dbhandle() # no args means use defaults from constants. 
      @mchandle = mchandle() # memcached -d -m 48 -u anthor  #to launch
      
      $stderr.print("\nNew consumer thread started, id = #{@id}")
      super #you can use 'super' to check the superclasses of this class for methods... like mixins. 
      
    rescue StandardError
      $stderr.print(".. exception in the Consumer object initialization: #{$!}")
       $@.each{|x| $stderr.print("\n    #{x}") }
      stop #cleanup
      raise "\nconsumer thread #{id} terminated: #{$!}"
    end
  end
  
  
  def run()
    begin 
    while (Time.now() - @age) < MAXAGE && @iterations < MAXITERATIONS #
      @iterations = @iterations + 1    
      @tsock = $q.deq 
        # choose a socket reading protocol module.... run it and get the results. 
        #run it through the loaded Module - in this case, Phttp.
        # get process from one module, and pizimpresponse from another. 
        
        
        
        process(@tsock){earl} # call Process with a block. That block fills in the HTML response. 
        
        
        #process(@tsock){pizimpresponse} # call Process with a block. That block fills in the HTML response. 
        
        # the Modules loaded define process methods for handling the socket protocol. 
        # so the name remains 'process' whenther the module handles HTTP or FTP.
        # In the case of the Phttp module, it calls the 'responsebody' method, 
        # which forms the http body response. 
        # It's the 'payload of this whole process, so it's moved back to the consumer. 
        #
      @tsock.close
      $run ? Thread.pass : stop #sleep or suicide after processing 
      
    end # end the while loop
    $stderr.print("\nConsumer thread dying of old age. (age = #{@age}, after #{@iterations} runs.)")
    stop #cleanup the thread
    rescue StandardError
        $stderr.print("\n caught error in consumer thread #{@id} (now terminated): #{$!}")
        $@.each{|x| $stderr.print("\n   #{x}")}
        raise "\nconsumer thread #{@id} terminated: #{$!}"
    end
  end #end of run method
  
  def stop
    #try to clean up the thread to avoid leaving open handles, etc. 
    @mydevhandle.close() if  @mydevhandle
    $cthreads.delete_at($cthreads.index(Thread.current))
    #would be nice to be able to test the socket.
    #@tsock.flush if @tsock
    #@tsock.close if @tsock
    # raise PimpCeption # ATR commented 9/09 not sure why that was there. 
  end #end of stop method
end # end the consumer class

# The server class has queues for producer and consumer, and a function for the producer, which accepts connections and enqueues them. 
# 
class Server
  require 'cronodules.rb'
  # add a simple cron functionality to the server (in a thread)
  include Cronodule 
  require 'log_module.rb'
  # mix in the Logger module to give this thread access to the error logger.  
  include Logger  
  require 'persist_module'
  # mix in the Persist module for DB access. 
  include Persist  
  
  # create needed queues for producers and consumers. 
  def initialize()
    $stderr.print("\n initializing a p-server.")
    $cthreads = Array.new # consumers - needs to be global so threads can committ suicide.
    @pthreads = Array.new #producers
    $q = Queue.new # a FIFO queue for producer/consumer concurrency
    $consolethread = nil #the consle thread will bind to a socket and control things.
    @cron = nil
    super
  end#
  
  # fire up the server, create producer and consumer threads and make them ready to receive sockets.   
  def start 
    $consolethread = Thread.new{console}
    $consolethread[:logbuffer]= ["welcome to the logbuffer","use the command 'set viewlog = true' to see the log scroll by in the console.","use 'set loglevel = 4' to change the current loglevel"]
    
    INITIALPRODUCERS.times{|j| @pthreads.push(Thread.new{producer(j)})} 
    INITIALCONSUMERS.times{|i| $cthreads.push(Thread.new{Consumer.new.run})} #for some reason, ThreadGroup.add doesn't work.
    @cron =Thread.new{cron} #start the cron running in a thread
    
    $stderr.print("\n Started with #{$cthreads.length} workers. @run is #{$run}")
    while $run # main run loop 
    # make another thread if the consumer queue dropped below INITIALCONSUMERS or the queue has more than INITIALCONSUMERS waiting to run
    # indications we need more consumers: 
    # =>      1. there are a few items in the queue 
    # =>      2. there are fewer WAITING consumers than the initial number created (not enough idle consumers in the pool)  
    #         3. the number of consumers waiting is low (under 10%) compared to the total number of consumers.  
        
    if(($q.length > 1 || $q.num_waiting < INITIALCONSUMERS || ($q.num_waiting < ($cthreads.length / 10)) )  && $cthreads.length < MAXWORKERS)
       $stderr.print("\n ... need to spawn a Consumer: there are #{$q.length} waiting requests, and #{$q.num_waiting} idle consumers.")
      $cthreads.push(Thread.new{Consumer.new.run})
    end
      # every once in a while it would be worthwile to check the producer and consumer threads and make sure none of them 
      # got stuck.  Maybe check for non-responsive threads and then add them to a list to kill off after a while. 
      Kernel.sleep(0.1) #might be dangerous under high transient loads, as it limits how many consumers are spawned. 
      Thread.pass #should be better, but behaves oddly.  Test it some more. 
      
    end #end the run loop
    $stderr.print("\n Ending run loop. @run is #{$run}")
    stop # clean up threads, terminate
  end #end the start
  
  # carefully collect and stop all producer and consumer threads. 
  def stop
    $stderr.print("\n Server caught stop signal. Terminating..")
    counter =@pthreads.length 
    @pthreads.each{|x|x.join(0.5)} #kill off producers with half second limit
    $stderr.print("\n...#{counter} producers killed..") 
    counter =$cthreads.length
    $cthreads.each{|x|x.join(1)}
    $stderr.print("\n...#{counter} consumers killed..")
    $consolethread.join(1) #collect the console thread and kill it.
    Thread.main.exit 
  end
   
  # a producer bee to enqueue socket requests, so they can be taken up by consumer threads.
  #### NOTE: there can be no more than ONE producer: otherwise the additional producer -may- block the 
  # main thread. .. . . enq. seems to be totally blocking, INCLUDING the parent thread... 
  #ATR - 5/6/09 - not sure about that. 
  # more testing indicated... 
  # Note: while the consumer is an actual object, the producer is a function. It may not have it's own stack, variables, etc.  
  def producer(id)     
     Thread.current.priority = 2 #set a higher priority for the producer thread, since it's critical and fast. 
     loop{
       sock = $connection.accept #should return a socket.  #sock = $connection.accept_nonblock #doesn't work on  this OS
       $q.enq(sock) # main thread enqueues the request.
       Thread.pass #be kind, pass execution.
     }#end the loop
  end #end of daemon.
    
  # a console to process commands and give feedback. 
  # listens on a socket connection.   
  def console
        sock = $console.accept # return a socket.
        $stderr.print("\nConsole has a connection, sock is #{sock.class}")
        viewlog = true #show the log. 
        
        loop{
          #run automatically on console connection to show recent emergency errors.
          sock.puts "\n recent emergencies:#{$logbuffer[:emergency].size}" if $logbuffer[:emergency].size > 0 
          while  $logbuffer[:emergency].size > 0 
            it =  $logbuffer[:emergency].shift
            sock.puts("log:"  + it.to_s) if(viewlog)
          end
          
          
          while sock != nil
            line = sock.gets.chop #read a line, from class: IO ios.gets(sep_string=$/) => string or nil
            #experiment with this instead: socket.recvfrom_nonblock(maxlen) => [mesg, sender_sockaddr]
            
            case line 
            when "list"
              # show running threads and stats
                sock.puts("\n the queue is at: #{$q.length} waiting requests, and #{$q.num_waiting} threads available. ")  
                sock.puts "\n listing active threads "
                sock.puts "\n..there are #{@pthreads.length} producers:"
                @pthreads.each{|pp| sock.puts "producer is class #{pp.class} #{pp.to_s}" }
                sock.puts "\n..there are #{$cthreads.length} consumers:"
                $cthreads.each{|pp|pp.to_s}
                sock.flush

            when "quit"
              # kill off the server. 
              sock.puts "quitting! "
              $run = false # signal the main thread to quit. 
              break #leave the processing loop
            else
              #unhandled input
              sock.puts "unknown command: " << line
              sock.flush
            end #end the case
          end #end the while
          
        break if $run == false  #quit
        Thread.pass #be kind, pass execution in between input lines and log processing.            
        } #end the permanent loop

        sock.flush
        sock.close
        $stderr.print("\n ending the console...")
        Thread.exit #suicide        
  end #end of daemon.

end #end the Server class


#Kick off the server. 
shiz = Server.new()
shiz.start


__END__