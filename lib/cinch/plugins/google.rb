require 'cgi'
require "json"

module Cinch
  module Plugins
    class Google
      # FIXME doesn't work with google's markup
      include Cinch::Plugin
      enable_acl

      match(/g(?:oogle)? (?:(\d+) )?(.+)/)
      def execute(m, num_results, search_term)
        num_results = (num_results && num_results.to_i) || 1
        if num_results.to_i > config[:max_results]
          num_results = config[:max_results]
        end

        argument_string = CGI.escape(search_term)
        open("http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=#{argument_string}") do |http|
          json = JSON.parse(http.read)
          results = json["responseData"]["results"]
          results = results.select {|result| result["GsearchResultClass"] == "GwebSearch"}[0, num_results]

          if results.empty?
            m.reply "(no results)"
          else
            results.each do |result|
              m.safe_reply "[%s] %s - %s" % [search_term, result["url"], result["titleNoFormatting"]]
            end
          end
        end
      end
    end
  end
end
