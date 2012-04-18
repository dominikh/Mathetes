# encoding: utf-8
# Summarizes URLs seen in IRC.

# By Pistos - irc.freenode.net#mathetes

# $KCODE = 'u'

require 'cgi'
require 'json'
require 'nokogiri'
require 'timeout'
require 'open-uri'
require 'json'
require 'mechanize'

module Cinch
  module Plugins
    class URLSummarizer
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        @agent                          = Mechanize.new
        @agent.user_agent_alias         = "Linux Mozilla"
        @agent.max_history              = 0
      end

      # class ByteLimitExceededException < Exception
      # end

      # def fetch( url, limit = 10 )
      #   if limit == 0
      #     raise ArgumentError, 'HTTP redirect too deep'
      #   end

      #   @doc_text = ""
      #   uri = URI.parse( url )

      #   response = Net::HTTP.start( uri.host, 80 ) { |http|
      #     path = uri.path.empty? ? '/' : uri.path
      #     http.request_get( "#{path}?#{uri.query}" ) { |res|
      #       res.read_body do |segment|
      #         @doc_text << segment
      #         if @doc_text.length >= config[:byte_limit]
      #           raise ByteLimitExceededException.new
      #         end
      #       end
      #     }
      #   }

      #   case response
      #   when Net::HTTPSuccess
      #     response
      #   when Net::HTTPRedirection
      #     fetch( response[ 'location' ], limit - 1 )
      #   else
      #     rescue_exception do
      #       response.error!
      #     end
      #   end
      # end

      # def summarize_url( url )
      #   begin
      #     Timeout::timeout( 10 ) do
      #       fetch url
      #     end
      #   rescue EOFError, ByteLimitExceededException
      #     # > /dev/null
      #   end

      #   doc = Nokogiri::HTML( @doc_text )
      #   summary = nil

      #   catch :found do
      #     description = doc.at( 'meta[@name="description"]' )
      #     if description
      #       summary = description.attribute( 'content' ).to_s
      #       throw :found
      #     end

      #     title = doc.at( 'title' )
      #     if title
      #       summary = title.content
      #       throw :found
      #     end

      #     heading = doc.at( 'h1,h2,h3,h4' )
      #     if heading
      #       summary = heading.content
      #       throw :found
      #     end
      #   end

      #   if summary
      #     summary = summary.strip.gsub( /\s+/, ' ' )
      #     if summary.length > 10
      #       summary = summary.split( /\n/ )[ 0 ]
      #       "[#{Format(:bold, "URL")}] #{summary[ 0...160 ]}#{summary.size > 159 ? '[...]' : ''}"
      #     end
      #   end
      # rescue Timeout::Error
      #   "[URL - Timed out]"
      # rescue OpenURI::HTTPError => e
      #   case e
      #   when /403/
      #     "[URL - 403 Forbidden]"
      #   end
      # rescue RuntimeError => e
      #   if e.message !~ /redirect/
      #     raise e
      #   end
      # end

      listen_to :message
      def listen(m)
        return if m.channel && config[:channel_blacklist].include?(m.channel.name)
        return if m.user.nil? || m.user.authname.nil?

        URI.extract(m.message, ["http", "https"]).each do |link|
          uri = URI.parse(link)
          head = @agent.head(link)
          content_type = head["content-type"].to_s.split(";").first
          if !["text/html", "application/xhtml+xml"].include?(content_type) || head["content-length"].to_i > 200000
            next
          end

          page = @agent.get(link)
          title = page.title.gsub(/\s+/, " ").delete("\n")
          case uri.host
          when
            /pastebin/,
            /www\.pivotaltracker\.com/,
            /\d+\.\d+\.\d+\.\d+/
            # Blacklist; swallow and discard
          when "gist.github.com"
            owner = page.search("//div[@class='name']/a").inner_html

            # Get time
            age = Time.parse(page.search("//span[@class='date']/time").first["datetime"])
            age = age.strftime("%Y-%m-%d %H:%M")

            m.reply "[#{Format(:bold, "gist")}] %s (at %s, %s on %s)" % [
              title, uri.host, owner, age
            ]
          when "pastie.org"
            # Get time
            age = Time.parse(page.search("//span[@class='typo_date']").text)
            age = age.strftime("%Y-%m-%d %H:%M")

            m.reply "[#{Format(:bold, "pastie")}] %s (at %s, on %s)" % [
              title, uri.host, age
            ]
          when "twitter.com"
            if uri.fragment =~ /^!\/.+?\/status\/(\d+)$/
              open("https://twitter.com/statuses/show/#{$1}.json",
                 :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                json = http.read
                tweet = JSON.parse(json)
                escaped_text = CGI.unescapeHTML(tweet['text'])
                m.reply "[#{Format(:bold, "twitter")}] <#{tweet[ 'user' ][ 'screen_name' ]}> #{escaped_text}"
              end
            end
          when "github.com"
            if uri.path =~ /\/(.+?)\/commit\//
              commit = JSON.load(open(link + ".json", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))["commit"]

              project        = $1
              commit_message = Utilities::String.filter_string(commit["message"])
              author         = Utilities::String.filter_string(commit["author"]["name"])

              number_files            = {}
              [:modified, :added, :removed, :renamed].each do |field|
                number_files[field] = (commit[field.to_s] || []).size
              end

              s = "[#{Format(:bold, "github")}] [%s] <%s> %s {files +%s/-%s/~%s/mv%s}" %
                [project, author, commit_message, *number_files.values_at(:added, :removed, :modified, :renamed)]

              m.reply s
            end
          else
            title = page.title.gsub(/[\x00-\x1f]*/, "").gsub(/[ ]{2,}/, " ").strip rescue nil
            m.reply "[URL] " + title
          end
        end
      end
    end
  end
end
