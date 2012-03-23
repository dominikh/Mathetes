# Soviet Russia plugin
# See http://en.wikipedia.org/wiki/Russian_reversal#Russian_reversal

# By Pistos - irc.freenode.net#mathetes

require 'russian-reversal'
require "pstore"
raise "This plugin is currently broken."

module Cinch
  module Plugins
    class SovietRussia
      include Cinch::Plugin
      enable_acl

      def channel_init( channel )
        @channels.transaction do
          @channels[channel] ||= {
            :active => false,
            :interval => config[:default_interval],
            :last => 0,
          }
        end
      end

      def initialize(*args)
        super

        @channels = PStore.new( "soviet-russia.pstore" )
      end

      match(/sr (\S+)(?: (.+))?/)
      def execute(m, command, args)
        debug [command, args].inspect
        return if config[:ignored].include?( m.user.nick )

        args    = args.split(" ")
        channel = m.channel.name.downcase

        channel_init channel

        case command
        when 'off'
          @channels.transaction do
            @channels[channel][:active] = false
          end
          m.reply "Soviet Russia mode deactivated for #{channel}."
        when 'on'
          @channels.transaction do
            @channels[channel][:active] = true
          end
          m.reply "Soviet Russia mode activated for #{channel}."
        when /^int/
          int = ( args[0].to_i * 60 )
          @channels.transaction do
            @channels[channel][:interval] = int
          end
          m.reply "Soviet Russia interval for #{channel} set to #{ int / 60.0 } minutes."
        when 'test'
          reversal = RussianReversal.reverse( args.join(' ') )
          if reversal && ! reversal.strip.empty?
            m.reply "#{m.user.nick}: HA!  In Soviet Russia, #{reversal} YOU!"
          else
            m.reply "Stuff like that actually happens in Soviet Russia."
          end
        end
      end

      listen_to :channel, method: :on_channel
      def on_channel(m)
        return if config[:ignored].include?(m.user.nick)
        channel = m.channel.name.downcase
        channel_init channel
        @channels.transaction do
          delta = Time.now.to_i - @channels[channel][:last]
          if @channels[channel][:active] && delta > @channels[channel][:interval]
            begin
              reversal = RussianReversal.reverse( message.text )
              if reversal && ! reversal.strip.empty?
                m.reply "#{m.user.nick}: Ha!  In Soviet Russia, #{reversal} YOU!"
                @channels[channel][:last] = Time.now.to_i
              else
                @bot.loggers.debug "No SR for \"#{message}\""
              end
            rescue Exception => e
              if e.message !~ /sentence has no linkages/
                @bot.loggers.exception(e)
              end
            end
          end
        end
      end
    end
  end
end
