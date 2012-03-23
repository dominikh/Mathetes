require 'open-uri'
require 'nokogiri'

module Cinch
  module Plugins
    class Pun
      include Cinch::Plugin
      enable_acl

      match("pun")
      def execute(m)
        doc = Nokogiri::HTML( open( "http://www.punoftheday.com/cgi-bin/randompun.pl" ) )
        m.reply doc.search( '#main-content p' )[ 0 ].inner_text
      end
    end
  end
end
