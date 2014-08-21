#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
  
  ##To DO
  ## Halt the app cleanly if the DB connection fails. Otherwise it just tries over and over and over. 
  
  
module Persist
  # the Persist module mixes in connections to the memcached and database
  # so that each worker thread has a static handle to each. 
  # if testing shows that to be a bad idea (when there are many worker threads)
  # then maybe we can rethink and have a pool of data connections shared between the worker threads. 
  # that has more complex mutex issues. 
  
  # note: since this is a mixin module, it needs to be mixed into an object. 
  # which means for threads, the thread needs to be an object and to mix this in.
  # in the current implementation, each thread is still part of the Server object.   
  
  # Also - 
  # use ruby  safe mode, 
  # use public/Private methods, 
  # and pass in a construct for the connection info 
  # from a constants file initially, so this can be reused. 
  
  require 'mysql' # load the mysql drivers
  require 'memcache' # the memcache drivers
  
  # not so sure what attributes need to be readable... 
  attr_reader :expiry, :active_handles
  
  def initialize
      $stderr.print("\nPersist: the Persist module initialized as mixin into #{self} ")
      @expiry = 60
      @active_handles = Hash.new
      # need to be careful when closing shared handles. 
      super # call super in case other Modules are also mixed in with initialization routines. 
  end
   
  # make the public methods only the end-use methods: query, select, count, etc. 
  public # declare the following public methods. 
  
    def sqlsafe(it)
      it.gsub(/[;]/,"...") #do some research on sql injection via ruby...
    end
  
    def strip(it)
      it.gsub(/["'`;]/,'') #maybe encode, to remove quotes and stuff. 
    end
 
    # simple convenience method for db counts
    def dbcount(dbhandle,field,table,where)
      result = dbquery(dbhandle,"SELECT COUNT(#{field}) FROM #{table} WHERE #{where} LIMIT 1")
   	  return (result !=nil ? result.fetch_row()[0].to_i : -1)
    end

    # Simple select, uses dbquery
    def dbselect(dbhandle,table,what,where)
      dbquery(dbhandle,"SELECT #{what} FROM #{table} WHERE #{where}")
    end

    # simple insert, returns the row_id
    # does not use the dbQuery method.
    def dbinsert(dbhandle,table,what)
      begin
      q = "INSERT INTO #{table} SET #{what}"
      dbhandle.query(sqlsafe(q))
   	  dbhandle.insert_id
      rescue StandardError
        logit(ERROR,"dbinsert")
        raise
      end
    end

    # does not use the dbQuery method.
    def dbinsert_delayed(dbhandle,table,what)
      begin
      dbhandle.query(sqlsafe("INSERT DELAYED INTO #{table} SET #{what}"))
      rescue StandardError
        logit(ERROR,"dbinsert_delayed")
        raise
      end
    end

    # update a single row, not so strong.  Fails if the item does not exist. 
    def dbupdate(dbhandle,table,set,where)
       q = "update #{table.to_s} SET #{set.to_s} WHERE #{where.to_s} limit 1"
       dbquery(dbhandle,q)
    end

    # a strong update:  adds a row if none exists (forces an iinsert).
    # using this method is not only easier, it also means no redundant rows. 
    def dbupdate!(dbhandle,table,set,where)
      result = dbselect(dbhandle,table,"*",where)  #do the insert
      if(result == nil || result.num_rows == 0)
        what = (set+','+where).gsub(/AND|and/,',') #still missed mixed case..
        #$stderr.print("\n update! converted this:   #{set + where}to this:   #{what}")
        rowid = dbinsert(dbhandle,table,what)
      else  # do the update
        q = "update #{table.to_s} SET #{set.to_s} WHERE #{where.to_s} limit 1"
        dbquery(dbhandle,q)
      end
    end

    # it might be fun to evaluate the where clause, and fail this if it just evaluates 'true' like "1=1, etc)"
    def dbdeleteone(dbhandle,table,where)
       q = "DELETE FROM #{table.to_s} WHERE #{where.to_s} limit 1"
       dbquery(dbhandle,q)
    end

    
  # Since this is a module Mixin - these methods are available to the object mixing them in. 
  #declare the following private methods. 
  private 
  
  # returns a handle to the db - reuses existing handles if they are asked for again.
  def dbhandle(user=SQLREADACCOUNT,pass=SQLREADPASS, indb=SQLDFLTDB)
    $stderr.print("\n debug: got user #{user} pass #{pass}  indb is #{indb} (SQLDFLTDB is... #{SQLDFLTDB})")
    # for some incredibly strange reason, indb reads as monet_development every other time a consumer is instantiated. 
    # despite that not being anywhere in the code.  
    begin
      @active_handles = Hash.new unless defined?(@active_handles) # pop active database handles into this hash with the (user,pass,db) string as a key, so they can be reused.    
      key = (user.to_s+pass.to_s+indb.to_s)
      if(@active_handles.has_key?(key))
        handle = @active_handles[key]
      else
        handle = Mysql.real_connect(SQLMASTER,user,pass,SQLDFLTDB)  #note redundant use of the SQLDFLTDB. using indb gets overwritten with other db names for some crazy reason. 
    	  @active_handles.store(key,handle)
      end
	  return handle
	  rescue Mysql::Error => theerror
  	  # rather than logging it, just halt. 
	    # logit(CRITICAL,"dbhandle")
	    $stderr << "\n failed to open handle..... " << theerror
	    # and exit ... ATR 2010 fix for Mogreet production
	    exit
	    #raise "error in Persist::dbhandle - #{theerror}"
	    return nil #return nil to indicate a problem connecting.
    end
  end # end dbhandle
  
  #return a handle to the secre_sauce DB, allowing for use of stored proceedures. 
  def secret_handle(user=SQLSECRETACCOUNT,pass=SQLSECRETPASS, indb=SQLSECRETDB)
     begin
       # pop active database handles into this hash with the (user,pass,db) string as a key, so they can be reused.    
       @active_handles = Hash.new unless defined?(@active_handles) 
       key = (user.to_s+pass.to_s+indb.to_s)
       if(@active_handles.has_key?(key))
         handle = @active_handles[key]
         $stderr.print("\n re-using this handle: #{key}")
       else
        handle = Mysql.real_connect(SQLSECRET,user,pass,SQLSECRETDB,SQLPORT.to_i,nil,Mysql::CLIENT_MULTI_RESULTS)
     		handle.query_with_result=false #force  manual return of result sets, allowing for multiple results. 
     	  @active_handles.store(key,handle)
     	  $stderr.print("\n creating new db handle:  #{key}")
       end
 	  return handle
 	  rescue Mysql::Error => theerror

 	    logit(CRITICAL,"secret_handle")
 	    raise "error in Persist::secret_handle - #{theerror}"
 	    return nil #return nil to indicate a problem connecting.
     end
  end # end secret_handle
  
  #takes a full query, returns the result. Used mainly for selects.
  def dbquery(dbhandle,q)
    begin
      #$stderr.print("\n Here's the dbquery: #{sqlsafe(q)}  \n" )
 	    dbhandle.query(sqlsafe(q))
    rescue Mysql::Error => theerror
      logit(ERROR,"dbquery")
      raise "error in Persist::dbquery - #{theerror}"
    end
  end
  

### Simple memcached methods. 

  # return a handle to the given memcached
  def mchandle(namespace="pimp")
    begin
    MemCache.new(MEMCACHEDHOSTS, :namespace => namespace, :multithread => true)
    rescue MemCache::MemCacheError =>error
      logit(CRITICAL)
      raise "Persist:mchandle:  #{theerror}"
    end
  end
  
  # put to memcached
  def mcput(mchandle,key,value,expiry=@expiry )
    begin
      $stderr.print("\n---mcput: memcache insert  #{key}, expiry in #{expiry} seconds")
      mchandle.set(key,value,expiry) 
    rescue MemCache::MemCacheError => theerror
      logit(ERROR,"mcput")
      raise "Persist:mcput:  #{theerror}"
    end
  end
  
  # get from memcached
  def mcget(mchandle,key)
     begin
       mchandle.get(key)
      rescue MemCache::MemCacheError => theerror
        logit(ERROR,"mcget")
        raise "Persist:mcget:  #{theerror}"
      end
  end
  
  # Get from memcached or DB,  
  # On a DB hit, convert the result to an array of rows, each row is a hash of columns, in string format, to match how db results are 
  # cached in the wrapput, like [{val=>"one",uri=>"two"}] and insert in the memcached. 
  def wrapget(mchandle,dbhandle,table,what,where)
    begin
    mckey = (where.gsub(/AND|and/,'') +'_'+ what +'_'+ table   ).gsub(/[^a-zA-Z0-9_]/,'')
    result = mcget(mchandle,mckey)
    if(result != nil)
      #logit(DEBUG,"dbcache HIT")
    else
      #logit(DEBUG,"dbcache MISS")
      result = dbselect(dbhandle,table,what,where)
      if(result.num_rows == 0)  # nothing returned.
        result=[] #return an empty array. 
        #logit(DEBUG,"db MISS")
      else #cache the hit for next time.
        #logit(DEBUG,"db HIT") 
        cache_this = Array.new
        result.each_hash{|x| cache_this.push(x)}
        mcput(mchandle,mckey,cache_this)
        result = cache_this #replace the result to pass out. 
      end
    end    
    result #return result, which is always an array of hashes, with the value encoded.  
  rescue
    logit(ERROR,"wrapget")
    raise
  end
  end  
  
  # wrapput: totally generic, no set db or ms. 
  # to make the mckey, strip the values from set, so that hval=123,hkey="shiz" gets condensed to hvalhkey, just for the purposes of setting the mc key. 
  # to memcached, insert an array of hash rows based on the sql, so "SET val= 'one', uri='two'" becomes [{val=>"one",uri=>"two"}]
  # It turns out that each hash value needs to be encoded as well, prior to storage. 
  def wrapput(mchandle,dbhandle,table,set,where)
    begin
    
    mckey = (where.gsub(/AND|and/,'') +'_'+ set.gsub(/=.*?,|=.*$/,'') +'_'+ table).gsub(/[^a-zA-Z0-9_]/,'')
    #mckey="hello" #for debug?
    $stderr.print("\n in wrapput, the mckey is #{mckey}")
    dbupdate!(dbhandle,table,set,where)
    set_hash = {}
    set.split(',').each{|item| kv = item.split('='); set_hash.store(kv[0],kv[1])}
    $stderr.print("\n wrapput - here's the hash we are storing in the mc:  #{[set_hash]}, it is class: #{[set_hash].class} ")
    mcput(mchandle,mckey,[set_hash]) 
    rescue
      logit(ERROR,"wrapput")
      raise
    end
  end
  
  
  def wrapreadfile(mchandle,filename)
    begin
      # override the content-type based on file extension. 
      ftype = case filename[/\..*/]
        when ".css"
          'Content-Type: text/css'
        when ".txt"
          'Content-Type: text/plain'
        when ".js"  
          'Content-Type: text/javascript'
        when '.json'
          'Content-Type: application/json'
        when '.xml'
          'Content-Type: text/xml'
        when '.htm','.html'
          'Content-Type: text/html'
        else 
          'Content-Type: application/octet-stream'
      end
      $stderr << "\n setting filetype to " << ftype
      #replace the content-type in place in the array
      @responseHeaders[@responseHeaders.index('Content-Type: text/html')] = ftype
      $stderr << "\n ok, @responseHeaders set to: \n " <<  @responseHeaders.inspect
       
      
      mckey = 'file_'+filename.gsub(/[^a-zA-Z0-9_]/,'')
      result = mcget(mchandle,mckey)
      if(result != nil)
        #$stderr.print("filecache HIT. ")
        result
      else
        #$stderr.print("filecache miss. ")
        cleanfile = filename.gsub(/\.\/|\.\.\/|\/\/|:/,'/') #won't allow climbing out of directories
        #$stderr.print("\n readfile is looking for: "+cleanfile)
        result = File.open(cleanfile,(File::RDONLY | File::NONBLOCK)) {|io| io.read()}
        mcput(mchandle,mckey,result)
        result
      end #end if cache hit. 
    rescue EOFError
      $stderr.print("\n unexpected EOF.")
      raise
    rescue IOError => e
      logit(DEBUG,"unexpected fileIO error:" << e )
       raise Error404
    rescue Errno::ENOENT
       raise Error404
    end 
  end
end #end the data module
