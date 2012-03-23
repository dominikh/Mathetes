# This script polls the Twitter API, echoing new messages to IRC.

# By Pistos - irc.freenode.net#mathetes

require 'twitter'
require 'time'
require 'yaml'
require 'rexml/document'
require 'cgi'

module Cinch
  module Plugins
    class Twitter
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        ::Twitter.configure do |c|
          c.consumer_key       = config[:consumer_key]
          c.consumer_secret    = config[:consumer_secret]
          c.oauth_token        = config[:oauth_token]
          c.oauth_token_secret = config[:oauth_token_secret]
        end

        @last_search_id = Hash.new
        @seen = Hash.new { |hash, key| hash[key] = [] }

        Timer(config[:poll_interval]) do
          poll_timeline
          poll_searches
        end
      end

      # The first time this is run, it just gets the most recent tweet and doesn't output it.
      def poll_timeline
        opts = @last_id ? { :since_id => @last_id } : {}
        tl = ::Twitter.home_timeline(opts)
        if tl.any?
          if @last_id.nil?
            @last_id = tl[ 0 ].id.to_i
          else
            tl.reverse!
            tl.reverse_each do |tweet|
              say_tweet tweet
            end
          end
        end
      end

      def poll_searches
        config[:searches].each do |search_term,channels|
          last_id = @last_search_id[search_term]
          fetched = ::Twitter.search(search_term, since_id: last_id)
          max_id = fetched.max_by {|f| f.id}
          max_id &&= max_id.id

          if max_id.to_i > last_id.to_i
            @last_search_id[search_term] = max_id
            next if last_id.nil?
            fetched.each do |tweet|
              say_search_tweet search_term, tweet, channels
            end
          end
        end
      end

      def clean_text(text)
        REXML::Text::unnormalize(text.gsub( /&\#\d{3,};/, '?' ).gsub( /\n/, ' ' ))
      end

      def say_tweet(tweet)
        tweet_id = tweet.id.to_i
        return  if tweet_id < @last_id
        @last_id = tweet_id
        src = tweet.user.screen_name
        text = clean_text( tweet.text )
        alert = "[#{Format(:bold, "twitter")}] <#{src}> #{text}"
        channels = config[:channels][src]
        return unless channels
        channels.each do |channel|
          if ! @seen[ channel ].include?( tweet_id )
            Target(channel).safe_send alert
            @seen[ channel ] << tweet_id
            lang, tr = translate( text )
            if lang && tr
              Target(channel).send "[#{Format(:bold, "twitter")}] (#{lang}) <#{src}> #{tr}"
            end
          end
        end
      end

      def say_search_tweet( search_term, tweet, channels )
        tweet_id = tweet[ 'id' ].to_i
        src = tweet[ 'from_user' ]
        text = clean_text( tweet[ 'text' ] )
        if config[:filters].find { |f| f =~ text }
          @bot.loggers.debug "[twitter] Filtered: #{text}"
          return
        end

        alert = "[#{Format(:bold, "twitter")}] [#{search_term[0..15]}] <#{src}> #{text}"
        channels.each do |channel|
          if ! @seen[ channel ].include?( tweet_id )
            Target(channel).send alert
            @seen[ channel ] << tweet_id
            lang, tr = translate( text )
            if lang && tr
              Target(channel).send "[#{Format(:bold, "twitter")}] (#{lang}) <#{src}> #{tr}"
            end
          end
        end
      end

      def translate(s)
        return if !defined? Mathetes::Plugins::Translate
        lang_source = Translate.detect(s, @bot)
        if lang_source && lang_source != 'en'
          tr = Translate.translate( s, lang_source, @bot )
          [ lang_source, tr ]
        end
      end
    end
  end
end
