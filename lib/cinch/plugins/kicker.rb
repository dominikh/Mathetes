# kicker.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

require "open-uri"
require "cgi"

module Cinch
  module Plugins
    class Kicker
      include Cinch::Plugin

      listen_to :channel
      def listen(m)
        nick = m.user.nick
        speech = m.message
        return unless config[:channels].find { |c| c.downcase == m.channel.name.downcase }

        config[:watchlist].each do |watch_nick, watchlist|
          next unless watch_nick === nick

          watchlist.each do |watch|
            watch[ :regexps ].each do |r|
              next unless r =~ speech

              victim = User($1 || nick)
              if ! watch[ :exempted ] || ! watch[ :exempted ].include?( victim )
                reasons = watch[ :reasons ]
                m.channel.kick(victim, reasons.sample) # TODO does this work yet?
                return
              end
            end
          end
        end
      end
    end
  end
end
