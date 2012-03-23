# This script polls RSS feeds, echoing new items to IRC.

# By Pistos - irc.freenode.net#mathetes

require 'mvfeed'

module Cinch
  module Plugins
    class RSS
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        @seen  = Hash.new { |hash,key| hash[ key ] = Hash.new }
        @first = Hash.new { |hash,key| hash[ key ] = true }

        config[:feeds].each do |uri, data|
          Timer(data[:interval]) do
            poll_feed(uri, data)
          end
        end
      end

      def poll_feed( uri, data )
        rescue_exception do
          feed = Feed.parse( uri )
          feed.children.each do |item|
            say_item uri, item, data[ :channels ]
          end
          @first[ uri ] = false
        end
      end

      def zepto_url( url )
        URI.parse( 'http://z.pist0s.ca/zep/1?uri=' + CGI.escape( url ) ).read
      end

      def say_item( uri, item, channels )
        return  if ! item.respond_to? :link

        if item.respond_to?( :author ) && item.author
          author = "<#{item.author}> "
        end

        alert = nil

        channels.each do |channel|
          id = item.link
          if ! @seen[ channel ][ id ]
            if ! @first[ uri ]
              if alert.nil?
                url = item.link
                if url.length > 28
                  url = zepto_url( item.link )
                end
                alert = "[#{Format(:bold, "rss")}] #{author}#{item.title} - #{url}".gsub( /\n/, '' )
              end
              Channel(channel).send alert
            end
            @seen[ channel ][ id ] = true
          end
        end
      end
    end
  end
end

