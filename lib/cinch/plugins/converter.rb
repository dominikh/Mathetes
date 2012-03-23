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
      enable_acl

      match(/(?:conv(?:ert)|calc) +(.*)$/)
      def execute(m, arg)
        # FIXME currency conversions do not work
        arg = CGI.escape(arg)
        open("http://www.google.com/search?q=#{arg}") do |html|
          answered = false
          html.read.scan(/<h2.*style="font-size:138%">\s*(.+?)\s*<\/h2>/m) do |result|
            stripped_result = CGI.unescapeHTML( result[ 0 ] )
            stripped_result.gsub!(/<sup>(.+?)<\/sup>/, "^(\\1)")
            stripped_result.gsub!(/<font size=-2> <\/font>/, "")
            stripped_result.gsub!(/<[^>]+>/, "")
            stripped_result.gsub!(/&times;/, "x")
            stripped_result.delete("\n")
            stripped_result.gsub!(/\s+/, " ")
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
