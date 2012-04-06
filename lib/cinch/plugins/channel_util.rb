module Cinch
  module Plugins
    class ChannelUtil
      include Cinch::Plugin
      enable_acl

      match("op", method: :op)
      match(/join (\S+)/i, method: :join)
      match(/part (\S+)/i, method: :part)

      def op(m)
        if m.channel
          User("ChanServ").send("OP #{m.channel}")
        end
      end

      def join(m, channel)
        Channel(channel).join
      end

      def part(m, channel)
        Channel(channel).part
      end
    end
  end
end
