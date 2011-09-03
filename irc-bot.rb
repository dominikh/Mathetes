require 'traited'
require 'yaml'
require 'pp'

Thread.abort_on_exception = true

def escape_quotes( s )
  temp = ""
  s.each_byte do |b|
    if b == 39
      temp << 39
      temp << 92
      temp << 39
    end
    temp << b
  end
  temp
end

module Mathetes
  DO_LOAD_CONF = true
  DONT_LOAD_CONF = false

  class IRCBot
    # TODO this will require some tinkering, and Cinch 1.2.0 (unloading feature)
    def reset( load_conf = DO_LOAD_CONF )
      puts "Resetting..."

      kill_threads
      unsubscribe_listeners
      parted = part_channels
      if load_conf
        @conf = YAML.load_file 'mathetes-config.yaml'
      end
      initialize_plugins
      join_channels parted

      puts "Reset."
    end

    # TODO won't be needed
    def kill_threads
      if @threads
        @threads.each do |t|
          t.kill
        end
      end
      @threads = Array.new
    end

    # TODO won't be needed
    def unsubscribe_listeners
      return  if @hooks.nil?
      @hooks[ :JOIN ].each do |hook|
        @irc.unsubscribe hook
      end
    end

    def part_channels( channels = nil )
      if @irc.connected?
        channels ||= @irc.channels.channels
        @irc.send_part 'Parting.', *channels
      end
      channels || []
    end

    # --------------------------------------------

    def ban( user, channel, seconds = 24 * 60 * 60 )
      @irc.send_raw( 'MODE', channel, '+b', user.hostmask.to_s )
      Thread.new do
        sleep seconds
        @irc.send_raw( 'MODE', channel, '-b', user.hostmask.to_s )
      end
    end

    # --------------------------------------------

    def new_thread( &block )
      t = Thread.new do
        begin
          block.call
        rescue Exception => e
          # TODO use the built-in Cinch method to capture exceptions
          $stderr.puts "Exception in thread: #{e.class}: #{e}"
          $stderr.puts e.backtrace.join( "\n\t" )
        end
      end
      @threads << t
      t
    end

  end
end

require "cinch"
require "cinch/plugins/identify" # DEP cinch-identify

module Cinch
  module Plugins
    class RequestOpOnJoin
      include Cinch::Plugin

      listen_to :join
      def listen(m)
        return if m.user != @bot
        return if ! config[:channels].include?(m.channel.name)
        User("ChanServ").send "OP #{m.channel}"
      end
    end
  end
end

include Cinch
mathetes = Bot.new do
  configure do |c|
    conf = YAML.load_file 'mathetes-config.yaml'

    c.server   = conf['server']['host']
    c.nick     = conf['nick']
    c.user     = "Mathetes"
    c.realname = "Mathetes Christou"
    c.channels = conf['channels'].map { |h| h["name"] }

    c.plugins.plugins = [Plugins::RequestOpOnJoin]

    if conf['password']
      c.plugins.plugins << Plugins::Identify
      c.plugins.options[Plugins::Identify] = {
        :username => conf['nick'],
        :password => conf['password'],
        :type     => :nickserv,
      }
    end

    c.plugins.options[Plugins::RequestOpOnJoin] = {
      :channels => conf['channels'].select { |h| h["ops"] }.map { |h| h["name"] },
    }

    c.plugins.options[Plugins::ChannelUtil] = {
      :admins => ["Pistos"],
    }

    # TODO load all plugins from config
  end
end

File.open( 'mathetes.pid', 'w' ) do |f|
  f.puts Process.pid
end

Signal.trap( 'HUP' ) do
  # TODO well, try to figure out the reload thing...
end

# TODO support filtering (ignoring) certain people/hostmasks

mathetes.start
