require 'cgi'
require 'open-uri'
require 'mathetes/web_scrape'

module Cinch
  module Plugins
    class Etymology
      include Cinch::Plugin

      match(/etym(?:ology)? (.+)/)
      def execute(m, term)
        arg = CGI.escape(term)
        hits = WebScrape.scrape(
                                "http://www.etymonline.com/index.php?term=#{ arg }",
                                /<dt(?: class="highlight")?>(.+?)<\/dd>/m,
                                arg
                                )

        if hits.empty?
          m.reply "[#{terms}] No results."
        else
          hits.each do |hit|
            m.reply "[#{terms}] #{hit}"
          end
        end
      end
    end
  end
end
