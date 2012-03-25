require "cinch"

module Cinch
  module Plugin
    module ClassMethods
      def enable_acl
        hook(:pre, :for => [:match], :method => lambda {|m| check_acl(m)})
      end
    end

    def check_acl(message)
      shared[:acl].check(message, self)
    end
  end
end

require "cinch/plugins/channel_util"
require "cinch/plugins/converter"
require "cinch/plugins/dictionary"
require "cinch/plugins/down_for_me"
require "cinch/plugins/etymology"
require "cinch/plugins/github_hook"
require "cinch/plugins/google_fight"
require "cinch/plugins/google"
require "cinch/plugins/kicker"
require "cinch/plugins/last_spoke"
require "cinch/plugins/memo"
require "cinch/plugins/pun"
require "cinch/plugins/rss"
require "cinch/plugins/request_op_on_join"
require "cinch/plugins/russian_roulette"
require "cinch/plugins/spell"
require "cinch/plugins/time_date"
require "cinch/plugins/translate"
require "cinch/plugins/twitter"
require "cinch/plugins/url_summarizer"
require "cinch/plugins/ideone"
require "cinch/plugins/plugin_management"
require "cinch/plugins/haiku"
require "cinch/plugins/eval"

require 'yaml'

module Cinch
  module Extensions
    class ACL
      def initialize
        @defaults = {:authname => {}, :channel => {}}
        @acls     = {
          :authname => Hash.new {|h, k| h[k] = {}},
          :channel  => Hash.new {|h, k| h[k] = {}},
        }
      end

      # @param [:authname, :channel] type
      # @param [Class] plugin
      # @param [:allow, :disallow] value
      def set_default(type, plugin, value)
        @defaults[type][plugin] = value
      end

      # @param [:authname, :channel] type
      # @param [Class] plugin
      # @param [String] name
      # @return [void]
      def allow(type, plugin, name)
        if type != :authname && type != :channel
          raise ArgumentError, "type must be one of [:authname, :channel]"
        end

        @acls[type][plugin][name] = :allow
      end

      # @param [:authname, :channel] type
      # @param [Class] plugin
      # @param [String] name
      # @return [void]
      def disallow(type, plugin, name)
        if type != :authname && type != :channel
          raise ArgumentError, "type must be one of [:authname, :channel]"
        end

        @acls[type][plugin][name] = :disallow
      end

      # @param [Message] message
      # @param [Plugin]  plugin
      # @return [Boolean]
      def check(message, plugin)
        channel_name  = message.channel && message.channel.name.irc_downcase(message.bot.irc.isupport["CASEMAPPING"])
        authname_name = message.user    && message.user.authname

        authname_allowed = get_acl(plugin, :authname, authname_name) == :allow
        channel_allowed  = channel_name.nil?  || get_acl(plugin, :channel,  channel_name) == :allow

        authname_allowed && channel_allowed
      end

      private
      # @param [Plugin] plugin
      # @param [:authname, :channel] type
      # @param [String] name
      # @return [:allow, :disallow]
      def get_acl(plugin, type, name)
        plugin = plugin.class
        @acls[type][plugin][name] || @defaults[type][plugin] || @defaults[type][nil]
      end
    end
  end
end

class MathetesBot < Cinch::Bot
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

mathetes = MathetesBot.new do
  configure do |c|
    c.load YAML.load_file 'config.yaml'

    Cinch::Plugins::Haiku.enable_acl

    acl = Cinch::Extensions::ACL.new
    # global defaults
    acl.set_default(:channel, nil, :allow)
    acl.set_default(:authname, nil, :allow)

    # ChannelUtil
    acl.set_default(:channel, Cinch::Plugins::ChannelUtil, :allow)
    acl.set_default(:authname, Cinch::Plugins::ChannelUtil, :disallow)
    acl.allow(:authname, Cinch::Plugins::ChannelUtil, "Pistos")
    acl.allow(:authname, Cinch::Plugins::ChannelUtil, "DominikH")

    # PluginManagement
    acl.set_default(:channel, Cinch::Plugins::PluginManagement, :allow)
    acl.set_default(:authname, Cinch::Plugins::PluginManagement, :disallow)
    acl.allow(:authname, Cinch::Plugins::PluginManagement, "Pistos")
    acl.allow(:authname, Cinch::Plugins::PluginManagement, "DominikH")

    # Eval
    acl.set_default(:channel, Cinch::Plugins::Eval, :allow)
    acl.set_default(:authname, Cinch::Plugins::Eval, :disallow)
    acl.allow(:authname, Cinch::Plugins::Eval, "DominikH")

    c.shared[:acl] = acl
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
