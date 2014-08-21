# copyright ATR - 12/08 
# ATR grants Mogreet a perpetual, nonexclusive, fully paid up worldwide right to use, modify, distribute and resell the p-server.
#Copyright (C) 2010  Anthony Rossano

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

# constants file for p-server
# store info like code root, DB access ,memcached access, etc here. 
# Then load or require as needed when the server runs. 

PVERSION = 0.11
NODENAME = "agnes"
HOSTNAME = Socket::gethostname.to_s

INITIALCONSUMERS = 1
INITIALPRODUCERS = 1 # watch this. It may need to be only 1. (it will work OK but begin to block and fail as concurrency goes up.)
MAXWORKERS = 1000 #max consumer threads. 
MAXAGE = (60*10) #each consumer lives for a max of  (10 minutes) a day. Extend this in production... Keeps handles fresh. 
MAXITERATIONS = 10000 #each consumer dies after this many runs.

# Ports to connect for console and all connections
CONSOLEPORT = 1336
CONNECTIONPORT = 80

#Default Log levels:
EMERGENCY = 0; ALERT=1; CRITICAL=2; ERROR=3   
WARNING=4; NOTICE=5; INFO=6; DEBUG=7
$currentloglevel = DEBUG # { EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG}

NEWLINE = 13.chr+10.chr #be explicit about what a new line is.
    
# sql constants here for default use, for more flexibility define your own when 
# creating the sql object. 
SQLMASTER = "localhost"
SQLSLAVE = "localhost"
SQLPORT = "3306"
SQLDFLTDB = "pdb" #

SQLWRITEACCOUNT = "dev" # writer
SQLREADACCOUNT = "dev" #dev #reader
SQLLOGACCOUNT = "dev" # writer
SQLLOGPASS = "dev" # writer
SQLWRITEPASS = "dev" #dev #writeme
SQLREADPASS = "dev" # readme

SQLSECRET = "localhost" #location of the db handling pii
SQLSECRETDB = "pdb" #
SQLSECRETACCOUNT = "secret"
SQLSECRETPASS = "secret"


# memcached constants. 
MEMCACHEDHOSTS = ["localhost"]

# code root
# so you can call scripts by a relative name
PCODEROOT = "/Users/anthor/Desktop/project_honeydoo"

# so you can have html, jpg, etc files served
PWEBROOT = "/Users/anthor/Desktop/project_honeydoo/webroot/"

# logfile location
LOGFILE = "/Users/anthor/Desktop/project_honeydoo/pserv.log"

## add Default Errors here
class PimpCeption < RuntimeError
  attr_reader :pimp
  def initialize(pimp)
    @pimp = pimp
  end
end

# hacked in constants for MOMS
LOCALNODE = Socket::gethostname.to_s
SESSIONID = 'foobar'



