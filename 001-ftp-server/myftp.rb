require 'optparse'
require 'logger'
require 'ostruct'
require 'socket'

class Myftp

  def self.parse(args)

    options = OpenStruct.new
    options.port = 10000
    options.host = "0.0.0.0"
    options.dir = "/home/ftpServer"

    opt_parser = OptionParser.new do |opts|
     
      opts.banner = "Usage: 001-ftp-server/myftp.rb [options]"

      opts.on("-p","--port=PORT","listen port") do |port|
        options.port = port
      end

      opts.on("--host=HOST","binding address") do |host|
        options.host = host
      end

      opts.on("--dir=DIR","change current directory") do |dir|
        options.dir = dir
      end

      opts.on_tail("-h","print help") do
        puts opts
        exit
      end
  
    end

    opt_parser.parse!(args)
    options
  
  end

  private
  def initialize

    options = self.class.parse(ARGV)
    @port = options.port
    @host = options.host
    @dir  = options.dir

    @logger = Logger.new(STDOUT)
    @socketSet = []
    @dataSocks = []
    @cmd = []
    @logged_in_users = []
    @username_password = {"anonymos" => "123456"}
    @username = ""
    @mode = ""
    @dataPort = 0

    @sever = TCPServer.new(@host,@port)
    @sever.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    @socketSet << @sever

    run

  end

  def run
    
    loop{
      state = select(@socketSet,nil,nil,nil)
      #state = [1,0,0,0]
      #@logger.info{"state = #{state}"}
      state[0].each { |sock|
      if sock == @sever
        newSock = sock.accept
        @socketSet << newSock
      else
        cmd = sock.gets.chomp.split(' ')
        cmd_execute(sock,cmd)
      end
      }
    }
  end

  def cmd_execute(sock,cmd)
  
    case cmd[0]
    
      when "USER" then
        if @logged_in_users.include?(sock) then
          sock.puts "230 User logged in"
        else
          sock.puts "331 User name okay, need password"
          @username = cmd[1]
        end

      when "PASS" then
        if @username == '' then
          sock.puts "332 Need account for login"
        elsif @username_password[@username] == cmd[1]
          sock.puts "230 User logged in"
          @logged_in_users << sock
        else
          sock.puts "530 Not logged in"
        end
     
      when "Passive" then
	if @mode == "" then
          enter_passive_mode(sock)
        else
          sock.puts "Already Passive Mode"
        end

       when "LIST" then
	 if @mode == "" then
           enter_passive_mode(sock)
	 end
	 sock.puts "150 File status okay; about to open data connection."
	 client = @dataSocks[0].accept
         client.puts(`ls -l`)
         sock.puts "226 Transfer complete."
         client.close  

       when "CWD" then
	 if @mode == "" then
 	   enter_passive_mode(sock)
	 end
	 if File.directory?(cmd[1]) && File.readable?(cmd[1]) then
	   Dir.chdir (cmd[1])
           sock.puts "250 CWD command successful"
	 else
	   sock.puts "550 No such file or directory"
	 end

      when "PWD" then
        if @mode == "" then
          enter_passive_mode(sock)
	end
        sock.puts "#{Dir.pwd}"

      when "RETR" then
	if @mode == "" then
          enter_passive_mode(sock)
	end
        #puts cmd
	if File.file?(cmd[1]) && File.readable?(cmd[1]) then
          puts @dataSocks
	  client = @dataSocks[0].accept
          puts "hello1"
	  file = open((File.absolute_path(cmd[1])))
          puts "hello2"
	  sock.puts "225 Data connection open"
	  client.puts(file.read)
	  client.close
	  sock.puts "226 Data connection close"
	else
	  sock.puts "550 No such file or directory"
	end

      when "STOR" then
	if @mode == "" then
          enter_passive_mode(sock)
        end
        client = @dataSocks[0].accept
        file = File.new(cmd[1],'w')
        sock.puts("225 Data connection open")
        file.syswrite(client.read)
	client.close
	sock.puts("226 Data connection close")

      else
        sock.puts "504 Command not implemented in that parameter"

    end

  end

  def enter_passive_mode(sock)
    dataSocket = TCPServer.new(0)
    @dataSocks << dataSocket
    @dataPort = dataSocket.addr[1]
    @mode = "Passive"
    sock.puts "227 Entering Passive Mode (127.0.0.1,#{@dataPort/256},#{@dataPort%256})"
  end

end

Myftp.new 
