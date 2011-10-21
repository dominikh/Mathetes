require 'cgi'
require 'open-uri'

module Cinch
  module Plugins
    class Google
      include Cinch::Plugin

      match(/g(?:google)? (?:(\d+) )?(.+)/)
      def execute(m, num_results, search_term)
        num_results ||= 1
        if num_results > config[:max_results]
          num_results = config[:max_results]
        end

        argument_string = CGI.escape(search_term)
        open( "http://www.google.com/search?q=#{argument_string}&safe=active" ) do |html|
          counter = 0
          html.read.scan /<a href="?([^"]+)" class=l.*?>(.+?)<\/a>/m do |match|
            url, title = match
            title.gsub!( /<.+?>/, "" )
            ua = search_term.gsub( /-?site:\S+/, '' ).strip
            m.reply "[#{ua}]: #{url} - #{title}"
            counter += 1
            break  if counter >= num_results
          end

          if counter == 0
            m.reply "(no results)"
          end
        end
      end
    end
  end
end
