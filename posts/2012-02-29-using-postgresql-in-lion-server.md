title: Using PostgreSQL included with Lion Server
date: 2012-02-29 12:00
tags: postgres macos
summary: Taming the Beast
---

In Lion Server Apple has moved from MySQL to PostgreSQL. You may find yourself
in a situation as I have where you wish to use a web application that requires
a database (WordPress for example), but don't wish to install MySQL when the
PostgreSQL server you have will do fine. There are a number of sources out
there on how to get this done, but the information seems to be scattered across
different corners of the internet. In particular these
[two](http://www.mactasia.co.uk/using-postgresql-in-lion-server)
[links](https://discussions.apple.com/thread/3199015?start=0&tstart=0) contain
all the information included in this post, but sifting through them was a bit
of a pain for me. For this reason I thought I would give my take on how to get
this done.

In short we are going to get PostgreSQL up and running, create a super user,
create a new database to be used with an application, create a user for that
application, and finally give that user access to the database. A quick note,
throughout the code in this article you will find entries that are prepended
by either lionserver:~ or databasename=#, these are command prompts and are not
meant to be typed in, but rather serve to distinguish commands from output.

First up we need to make sure that the PostgreSQL server is running. We're
going to do this with the command serveradmin. serveradmin is a command line
tool that allows you to control the various services that Lion Server has to
offer. In case you haven't used this tool before lets get a flavor of how it
works.

```bash
lionserver:~ serveradmin
Usage: serveradmin [-dhvx] [list | start | stop | status | fullstatus | settings | command] [ [ =  ]]
 
  -h, --help     display this message
  -v, --version  display version info
  -d, --debug    print command
  -x, --xml      print output as XML plist
Examples:
serveradmin list
        --Lists all services
serveradmin start afp
        --Starts afp server
serveradmin stop ftp
        --Stops ftp server
serveradmin status web
        --Returns current status of the web server
serveradmin fullstatus web
        --Returns more complete status of the web server
serveradmin settings afp
        --Returns all afp configuration parameters
serveradmin settings afp:guestAccess
        --Returns afp guestAccess attribute
serveradmin settings afp:guestAccess = yes
        --Sets afp guestAccess to true
serveradmin settings
        --Takes settings commands like above from stdin
serveradmin command afp:command = getConnectedUsers
        --Used to perform service specific commands
serveradmin command
        --Takes stdin to define generic command that requires other parameters
```
Ok that's great now we see that there is a list function lets try that.

```bash
lionserver:~  serveradmin list
serveradmin must be run as root
```
That's ok, we just need to run this command with a `sudo`.

```bash
lionserver:~ sudo serveradmin list
Password:
accounts
addressbook
afp
bonjour
calendar
certs
config
devicemgr
dhcp
dirserv
dns
filebrowser
info
ipfilter
jabber
mail
nat
netboot
network
nfs
notification
pcast
pcastlibrary
postgres
radius
sharing
signaler
smb
swupdate
vpn
web
wiki
xgrid
xsan
```
There it is the service is called postgres. Remember when we took a look how
the command worked? The usage info told us that we can start services, let's
try that.

```bash
lionserver:~ sudo serveradmin start postgres
postgres:state = "RUNNING"
```
And now PostgreSQL is running! Great, now comes the tricky part. Lion Server
has a special user that has access to the PostgreSQL server, the user name is
`_postgres`. But personally I don’t want to have to remember to log in as this
other user every time I want to manipulate PostgreSQL. So let's create a
PostgreSQL user for our username. First we need to log into PostgreSQL

```bash
lionserver:~ sudo -u _postgres psql template1
```
Then once in PostgreSQL we are going to create a role with the same username as
our login, for the purposes of this tutorial we will use username and a
randomly generated password QEGNRWXvxewJ42LdD. Then we will exit out of
PostgreSQL with the `\q` command.

```bash
template1=# CREATE ROLE username WITH superuser password 'QEGNRWXvxewJ42LdD';
template1=# \q
```
Next we want to add our login username to the PostgreSQL Users Group. The
easiest way to do this is to download the Server Admin Tools package. Launch
the tool and launch the Workgroups application, in the menu bar click View ->
Workgroups. You will need to login with an administrator account. Then in the
Workgroups application you will click View -> Show System Records. This will
expand the visible list to show everything. Find your login user, and then
click the Groups Tab. Find the PostgreSQL Users group and add it. Now you can
execute the `psql` command without fiddling around with the `_postgres` user.

By default, Lion Server will launch the postgres service with the option
`listen_addresses=""`, but our web app needs to connect to the service through
an IP address. So fire up your favorite text editor and point it towards
`/System/Library/LaunchDaemons/org.postgresql.postgres.plist`. In this file you
want to hunt down the line,

```bash
listen_addresses=
```
and replace it with

```bash
listen_addresses="127.0.0.1"
```
Finally we are ready to create our database and application user. Your
particular web application may have its own directions on this, if so you
should be done with this tutorial. But we will continue to complete a database
setup for WordPress.

We'll create our database with the convenient command `createdb`, create
`wordpressuser` with the command `createuser` and then login to the database.

```bash
lionserver:~ createdb wordpressdb
lionserver:~ createuser
Enter name of role to add: wordpressuser
Shall the new role be a superuser? (y/n) n
Shall the new role be allowed to create databases? (y/n) n
Shall the new role be allowed to create more new roles? (y/n) n
lionserver:~ psql -d wordpressdb
```
Once in PostgreSQL we'll give `wordpressuser` permissions on `wordpressdb`
and assign a randomly generated password.

```bash
wordpressdb=# GRANT ALL privileges ON DATABASE wordpressdb TO wordpressuse;
wordpressdb=# ALTER ROLE wordpressuser password 'NvUrYgnz4DRfbXm7y';
wordpressdb=# \q
```
And we’re done!
