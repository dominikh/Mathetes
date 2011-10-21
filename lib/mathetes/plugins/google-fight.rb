require 'cgi'
require 'nokogiri'
require 'open-uri'

module Cinch
  module Plugins
    class GoogleFight
      include Cinch::Plugin

      GOOGLEFIGHT_VERBS = [
                           [ 1000.0, "completely DEMOLISHES" ],
                           [ 100.0, "utterly destroys" ],
                           [ 10.0, "destroys" ],
                           [ 5.0, "demolishes" ],
                           [ 3.0, "crushes" ],
                           [ 2.0, "shames" ],
                           [ 1.2, "beats" ],
                           [ 1.0, "barely beats" ],
                          ]

      match(/(?:googlefight|gf) ([\S])+ (?:versus|v(?:s\.)?) ([\S]+)/)
      def execute(m, person1, person2)
        count1 = google_count(person1)
        count2 = google_count(person2)

        ratio1 = ( count2 != 0 ) ? count1.to_f / count2 : 99
        ratio2 = ( count1 != 0 ) ? count2.to_f / count1 : 99
        ratio = [ ratio1, ratio2 ].max
        verb = GOOGLEFIGHT_VERBS.find { |x| ratio > x[ 0 ] }[ 1 ]
        c1 = number_with_delimiter( count1 )
        c2 = number_with_delimiter( count2 )

        if count1 > count2
          msg = "#{person1} #{verb} #{person2}! (#{c1} to #{c2})"
        else
          msg = "#{person2} #{verb} #{person1}! (#{c2} to #{c1})"
        end
        m.reply msg, true
      end

      def number_with_delimiter( number, delimiter = ',' )
        number.to_s.gsub( /(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}" )
      end

      def google_count( terms )
        terms = CGI.escape( terms )
        doc = Nokogiri::HTML( open( "http://www.google.com/search?q=#{terms}" ) )
        doc.at("div[@id*=resultStats]").inner_text[/([0-9,]+)/,1].gsub(',','').to_i
      end
    end
  end
end
