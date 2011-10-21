# Uses Google to convert just about anything to anything else (units, currency, etc.)

# By Pistos - irc.freenode.net#geoshell

# Usage:
# !convert <any rough expression about conversion>
# e.g. !convert 20 mph to km/h

require "open-uri"
require "cgi"

module Cinch
  module Plugins
    class Converter
      include Cinch::Plugin

      match(/(?:conv(?:ert)|calc) +(.*)$/)
      def execute(m, arg)
        open( "http://www.google.com/search?q=#{ arg }" ) do |html|
          answered = false
          html.read.scan %r{<h2.*style="font-size:138%"><b>(.+?)</b></h2>}m do |result|
            stripped_result = CGI.unescapeHTML( result[ 0 ] )
            stripped_result = stripped_result.gsub( /<sup>(.+?)<\/sup>/, "^(\\1)" )
            stripped_result = stripped_result.gsub( /<font size=-2> <\/font>/, "" )
            stripped_result = stripped_result.gsub( /<[^>]+>/, "" )
            stripped_result = stripped_result.gsub( /&times;/, "x" )
            m.reply stripped_result
            answered = true
            break
          end
          if ! answered
            m.reply "(no results)"
          end
        end
      end
    end
  end
end
