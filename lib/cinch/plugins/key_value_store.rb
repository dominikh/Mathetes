require 'pstore'

module Cinch
  module Plugins
    class KeyValueStore
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super
        @h = PStore.new( "key-value.pstore" )
      end

      help "Usage: !i key = value     !i key"
      match(/i(?:nfo)? (.+)/)
      def execute(m, rest)
        if rest =~ /^\S+ (.+?)=(.+)/
          key, value = $1.strip, $2.strip
          @h.transaction {
            @h[ { :channel => m.channel.name, :key => key }.inspect ] = value
          }
          m.reply "Set '#{key}'."
        elsif rest =~ /^\S+\s+(.+)/
          key = $1.strip
          value = nil
          @h.transaction {
            value = @h[ { :channel => m.channel.name, :key => key }.inspect ]
          }
          if value
            m.reply value
          else
            m.reply "No value for key '#{key}'."
          end
        else
          m.reply "Usage: !i key = value    !i key"
        end
      end
    end
  end
end
