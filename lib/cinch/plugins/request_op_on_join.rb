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
