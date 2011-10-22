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

      def initialize(*args)
        super

        @twitter = ::Twitter::Base.new(::Twitter::HTTPAuth.new( config[ 'username' ], config[ 'password' ] ))
        @last_search_id = Hash.new
        @seen = Hash.new { |hash,key| hash[ key ] = Array.new }

        config[:searches].each do |search_term,channels|
          search = ::Twitter::Search.new( search_term )
          rescue_exception do
            fetched = search.fetch
            max_id = fetched[ 'max_id' ].to_i
            @last_search_id[ search_term ] = max_id
            channels.each do |channel|
              @seen[ channel ] << max_id
            end
          end
        end

        timer(config[:poll_interval]) do
          poll_timeline
          poll_searches
        end
      end

      # The first time this is run, it just gets the most recent tweet and doesn't output it.
      def poll_timeline
        rescue_exception do
          opts = @last_id ? { :since_id => @last_id } : {}
          tl = @twitter.friends_timeline( opts )
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
      end

      def poll_searches
        rescue_exception do
          config[:searches].each do |search_term,channels|
            search = ::Twitter::Search.new( search_term )
            last_id = @last_search_id[ search_term ]
            search.since( last_id )
            fetched = search.fetch
            if fetched[ 'max_id' ].to_i > last_id
              @last_search_id[ search_term ] = fetched[ 'max_id' ].to_i
              fetched[ 'results' ].each do |tweet|
                say_search_tweet search_term, tweet, channels
              end
            end
          end
        end
      end

      def clean_text( text )
        REXML::Text::unnormalize(
                                 text.gsub( /&\#\d{3,};/, '?' ).gsub( /\n/, ' ' )
                                 )
      end

      def say_tweet( tweet )
        tweet_id = tweet.id.to_i
        return  if tweet_id < @last_id
        @last_id = tweet_id
        src = tweet.user.screen_name
        text = clean_text( tweet.text )
        alert = "[\00300twitter\003] <#{src}> #{text}"
        channels = config[:channels][ src ] || [ 'Pistos' ]
        channels.each do |channel|
          if ! @seen[ channel ].include?( tweet_id )
            Target(channel).send alert
            @seen[ channel ] << tweet_id
            lang, tr = translate( text )
            if lang && tr
              Target(channel).send "[\00300twitter\003] (#{lang}) <#{src}> #{tr}"
            end
          end
        end
      end

      def say_search_tweet( search_term, tweet, channels = [ 'Pistos' ] )
        tweet_id = tweet[ 'id' ].to_i
        src = tweet[ 'from_user' ]
        text = clean_text( tweet[ 'text' ] )
        if config[:filters].find { |f| f =~ text }
          @bot.loggers.debug "[twitter] Filtered: #{text}"
          return
        end

        alert = "[\00300twitter\003] [#{search_term[0..15]}] <#{src}> #{text}"
        channels.each do |channel|
          if ! @seen[ channel ].include?( tweet_id )
            Target(channel).send alert
            @seen[ channel ] << tweet_id
            lang, tr = translate( text )
            if lang && tr
              Target(channel).send "[\00300twitter\003] (#{lang}) <#{src}> #{tr}"
            end
          end
        end
      end

      def translate( s )
        return  if ! defined? Mathetes::Plugins::Translate
        lang_source = Translate.detect(s, @bot)
        if lang_source && lang_source != 'en'
          tr = Translate.translate( s, lang_source, @bot )
          [ lang_source, tr ]
        end
      end
    end
  end
end
