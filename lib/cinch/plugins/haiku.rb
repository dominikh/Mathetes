require 'open-uri'
require 'nokogiri'

module Cinch
  module Plugins
    class Haiku
      include Cinch::Plugin
      enable_acl

      match "haiku"
      def execute(m)
        haikus = Nokogiri::HTML(
          open "http://www.dailyhaiku.org/haiku/?pg=#{ rand(220) + 1 }"
        ).search( 'p.haiku' ).to_a
        haiku_lines = haikus[ rand( haikus.size ) ].text.split( /[\r\n]+/ )
        width = haiku_lines.inject(0) { |max,line|
          line.length > max ? line.length : max
        }
        haiku_lines.each do |line|
          sleep 3
          m.reply( '     ' + line.center( width ) )
        end
      end
    end
  end
end
