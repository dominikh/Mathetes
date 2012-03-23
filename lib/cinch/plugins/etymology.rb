require 'cgi'
require 'open-uri'
require 'mathetes/web_scrape'

module Cinch
  module Plugins
    class Etymology
      include Cinch::Plugin
      enable_acl

      match(/etym(?:ology)? (.+)/)
      def execute(m, term)
        # FIXME this somehow prints inspected arrays...
        arg = CGI.escape(term)
        hits = Mathetes::WebScrape.scrape(
                                "http://www.etymonline.com/index.php?term=#{ arg }",
                                /<dt(?: class="highlight")?>(.+?)<\/dd>/m,
                                arg
                                )

        if hits.empty?
          m.reply "[#{term}] No results."
        else
          hits.each do |hit|
            m.reply "[#{term}] #{hit}"
          end
        end
      end
    end
  end
end
