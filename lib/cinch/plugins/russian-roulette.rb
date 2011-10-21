# russian-roulette.rb

# Kicks people based on public PRIVMSG regexps.

# By Pistos - irc.freenode.net#mathetes

module Cinch
  module Plugins
    class RussianRoulette
      Reasons = [
                 'You just shot yourself!',
                 'Suicide is never the answer.',
                 'If you wanted to leave, you could have just said so...',
                 "Good thing these aren't real bullets...",
                 "That's gotta hurt...",
                ]

      include Cinch::Plugin
      react_on :channel

      match(/roul(ette)?/)
      def execute(m)
        m.reply "*spin ..."
        sleep 4
        has_bullet = rand(6) == 0

        if has_bullet
          if config[:also_ban]
            m.channel.ban m.user

            timer(config[:ban_time] || 60, shots: 1) do
              m.channel.unban m.user
            end

            m.channel.kick m.user, "{ *BANG* #{Reasons.sample} }"
          end
        else
          m.reply "-click-"
        end
      end
    end
  end
end

