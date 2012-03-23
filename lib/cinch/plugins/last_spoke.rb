require "pstore"

module Cinch
  module Plugins
    class LastSpoke
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        @last_spoke = PStore.new( "lastspoke.pstore" )
        @spoke_start = PStore.new( "lastspoke-start.pstore" )
        @spoke_start.transaction { @spoke_start['time'] ||= Time.now }
      end

      listen_to :channel
      match(/(?:last|spoke|lastspoke) (\S+)/)

      def seconds_to_interval_string( seconds_ )
        seconds = seconds_.to_i
        minutes = 0
        hours = 0
        days = 0

        if seconds > 59
          minutes = seconds / 60
          seconds = seconds % 60
          if minutes > 59
            hours = minutes / 60
            minutes = minutes % 60
            if hours > 23
              days = hours / 24
              hours = hours % 24
            end
          end
        end

        msg_array = Array.new
        if days > 0
          msg_array << "#{days} day#{days > 1 ? 's' : ''}"
        end
        if hours > 0
          msg_array << "#{hours} hour#{hours > 1 ? 's' : ''}"
        end
        if minutes > 0
          msg_array << "#{minutes} minute#{minutes > 1 ? 's' : ''}"
        end
        if seconds > 0
          msg_array << "#{seconds} second#{seconds > 1 ? 's' : ''}"
        end

        msg_array.join( ", " )
      end

      def listen(m)
        return unless m.user

        nick = m.user.nick
        @last_spoke.transaction do
          @last_spoke[nick] = [Time.now, m.channel.name, m.message]
        end
      end

      def execute(m, target)
        target = Target(target)

        lst = nil
        @last_spoke.transaction { lst = @last_spoke[ target ] }
        if target == m.user
          m.reply "Um... you JUST spoke, to issue the command.  :)"
        elsif target == @bot
          m.reply "I don't watch myself."
        elsif lst.nil?
          m.reply "As far as I know, #{target.name} hasn't said anything."
          t = nil
          @spoke_start.transaction { t = @spoke_start[ 'time' ] }
          m.reply "I've been watching for #{seconds_to_interval_string( Time.now - t )}."
        else
          interval_string = seconds_to_interval_string( Time.now - lst[ 0 ] )
          message.answer "#{interval_string} ago, #{target.name} said: '#{lst[ 2 ]}' in #{lst[ 1 ]}."
        end
      end
    end
  end
end
