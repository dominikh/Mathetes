module Cinch
  module Plugins
    class ChannelUtil
      include Cinch::Plugin

      match("op", method: :op)
      match(/join (#[A-z0-9_-]+)/, method: :join)
      match(/part (#[A-z0-9_-]+)/, method: :part)

      def op(m)
        if m.channel
          User("ChanServ").send("OP #{m.channel}")
        end
      end

      def join(m, channel)
        return  if ! admin?( m.user )
        Channel(channel).join
      end

      def part(m, channel)
        return  if ! admin?( m.user )
        Channel(channel).part
      end

      private
      def admin?(user)
        config[:admins].include?( user.nick )
      end
    end
  end
end
