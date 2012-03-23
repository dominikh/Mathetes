require 'cgi'
require 'open-uri'
require "nokogiri"

module Cinch
  module Plugins
    class Etymology
      include Cinch::Plugin
      enable_acl

      match(/etym(?:ology)? (.+)/)
      def execute(m, term)
        arg = CGI.escape(term)
        code = open("http://www.etymonline.com/index.php?term=#{arg}").read
        code.scan(/<dt(?: class="highlight")?>(.+?)<\/dd>/m) do |match|
          text = Nokogiri::HTML(match.first).text
          m.safe_reply "[#{term}] #{text}"
        end
      end
    end
  end
end
