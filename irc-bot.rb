require "cinch"
require "cinch/plugins/identify" # DEP cinch-identify
require "cinch/plugins/channel_util"
require "cinch/plugins/converter"
require "cinch/plugins/dictionary"
require "cinch/plugins/down_for_me"
require "cinch/plugins/etymology"
require "cinch/plugins/github_hook"
require "cinch/plugins/google_fight"
require "cinch/plugins/google"
require "cinch/plugins/identify"
require "cinch/plugins/kicker"
require "cinch/plugins/last_spoke"
require "cinch/plugins/memo"
require "cinch/plugins/pun"
require "cinch/plugins/rss"
require "cinch/plugins/request_op_on_join"
require "cinch/plugins/russian_roulette"
require "cinch/plugins/sample"
require "cinch/plugins/spell"
require "cinch/plugins/time"
require "cinch/plugins/translate"
require "cinch/plugins/twitter"
require "cinch/plugins/url_summary"
require "cinch/plugins/web_scrape"

require 'traited'
require 'yaml'

Thread.abort_on_exception =

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

class Mathetes < Cinch::Bot
  def reset( load_conf = true )
    loggers.info "Resetting..."

    plugins.unregister_all
    if load_conf
      config.load YAML.load_file('mathetes-config.yaml')
    end
    plugins.register_plugins(@bot.config.plugins.plugins)

    loggers.info "Reset."
  end
end

mathetes = Mathetes.new do
  configure do |c|
    c.load YAML.load_file 'mathetes-config.yaml'
  end
end

File.open( 'mathetes.pid', 'w' ) do |f|
  f.puts Process.pid
end

Signal.trap( 'HUP' ) do
  mathetes.reset
end

# TODO support filtering (ignoring) certain people/hostmasks

mathetes.start
