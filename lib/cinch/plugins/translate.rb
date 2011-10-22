require 'cgi'
require 'open-uri'
require 'json'

module Cinch
  module Plugins
    class Translate
      include Cinch::Plugin

      # @return The two-letter language code of the language
      def self.detect( s, bot )
        text = CGI.escape( s ).gsub( '+', '%20' )
        google_response = open( "http://ajax.googleapis.com/ajax/services/language/detect?v=1.0&q=#{text}" ) { |h| h.read }
        r = JSON.parse( google_response )
        if r.nil?
          bot.loggers.debug "Failed to parse JSON for: #{google_response.inspect}"
        end
        if r && r[ 'responseData' ]
          r[ 'responseData' ][ 'language' ]
        end
      end

      # @return The translated text.
      def self.translate( s, lang_source, lang_dest = 'en', bot )
        text = CGI.escape( s ).gsub( '+', '%20' )
        url = "http://ajax.googleapis.com/ajax/services/language/translate?v=1.0&langpair=#{lang_source}%7C#{lang_dest}&q=#{text}"
        google_response = open( url ) { |h| h.read }
        r = JSON.parse( google_response )
        if r.nil?
          bot.loggers.debug "Failed to parse JSON for: #{google_response.inspect}"
        end
        if r && r[ 'responseData' ]
          r[ 'responseData' ][ 'translatedText' ]
        end
      end

      match(/^!tr(?:ans(?:late)?)? ([a-zA-Z-]{2,5}) ([a-zA-Z-]{2,5}) (.+)/)
      def execute(m, src, dest, text)
        if message.text =~ /^!tr\S* /
          translation = Translate.translate( text, src, dest, @bot )
          if translation
            m.reply "[tr] #{translation}"
          end
        end
      end
    end
  end
end
