# encoding: utf-8
# Summarizes URLs seen in IRC.

# By Pistos - irc.freenode.net#mathetes

# $KCODE = 'u'

require 'cgi'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'timeout'
require 'net/http'

module Cinch
  module Plugins
    class URLSummarizer
      class ByteLimitExceededException < Exception
      end

      def fetch( url, limit = 10 )
        if limit == 0
          raise ArgumentError, 'HTTP redirect too deep'
        end

        @doc_text = ""
        uri = URI.parse( url )

        response = Net::HTTP.start( uri.host, 80 ) { |http|
          path = uri.path.empty? ? '/' : uri.path
          http.request_get( "#{path}?#{uri.query}" ) { |res|
            res.read_body do |segment|
              @doc_text << segment
              if @doc_text.length >= config[:byte_limit]
                raise ByteLimitExceededException.new
              end
            end
          }
        }

        case response
        when Net::HTTPSuccess
          response
        when Net::HTTPRedirection
          fetch( response[ 'location' ], limit - 1 )
        else
          rescue_exception do
            response.error!
          end
        end
      end

      def summarize_url( url )
        begin
          Timeout::timeout( 10 ) do
            fetch url
          end
        rescue EOFError, ByteLimitExceededException
          # > /dev/null
        end

        doc = Nokogiri::HTML( @doc_text )
        summary = nil

        catch :found do
          description = doc.at( 'meta[@name="description"]' )
          if description
            summary = description.attribute( 'content' ).to_s
            throw :found
          end

          title = doc.at( 'title' )
          if title
            summary = title.content
            throw :found
          end

          heading = doc.at( 'h1,h2,h3,h4' )
          if heading
            summary = heading.content
            throw :found
          end
        end

        if summary
          summary = summary.strip.gsub( /\s+/, ' ' )
          if summary.length > 10
            summary = summary.split( /\n/ )[ 0 ]
            "[\00300URL\003] #{summary[ 0...160 ]}#{summary.size > 159 ? '[...]' : ''}"
          end
        end
      rescue Timeout::Error
        "[URL - Timed out]"
      rescue OpenURI::HTTPError => e
        case e
        when /403/
          "[URL - 403 Forbidden]"
        end
      rescue RuntimeError => e
        if e.message !~ /redirect/
          raise e
        end
      end

      listen_to :channel
      def listen(m)
        return  if m.channel && config[:channel_blacklist].include?( m.channel.name )

        m.user.whois
        return if m.user.authname.nil?

        speech = m.message
        case speech
        when %r{http://pastie},
          %r{http://pastebin},
          %r{http://github\.com/.*/blob},
          %r{http://gist\.github\.com},
          %r{http://www\.pivotaltracker\.com/story},
          %r{http://\d+\.\d+\.\d+\.\d+}
          # Blacklist; swallow and discard
        when %r{twitter\.com/(?:#!/)?\w+/status(?:es)?/(\d+)}
          open( "http://twitter.com/statuses/show/#{$1.to_i}.json" ) do |http|
            json = http.read
            tweet = JSON.parse( json )
            escaped_text = CGI.unescapeHTML( tweet[ 'text' ].gsub( '&quot;', '"' ).gsub( '&amp;', '&' ) ).gsub( /\s/, ' ' )
            m.reply "[\00300twitter\003] <#{tweet[ 'user' ][ 'screen_name' ]}> #{escaped_text}"
          end
        when %r{(http://github.com/.+?/(.+?)/commit/.+)}
          doc            = Nokogiri::HTML( open( $1 ) )

          project        = $2
          commit_message = doc.css( 'div.human div.message pre' )[ 0 ].content.delete("\n")
          author         = doc.css( 'div.human div.name a')[ 0 ].content

          number_files            = {}
          number_files[:modified] = doc.css( '#toc td.status.modified' ).size
          number_files[:added]    = doc.css( '#toc td.status.added'    ).size
          number_files[:removed]  = doc.css( '#toc td.status.removed'  ).size
          number_files[:renamed]  = doc.css( '#toc td.status.renamed'  ).size

          s = "[\00300github\003] [%s] <%s> %s {files +%s/-%s/~%s/mv%s}" %
            [project, author, commit_message, *number_files.values_at(:added, :removed, :modified, :renamed)]

          m.reply s
        when %r|(http://(?:[0-9a-zA-Z-]+\.)+[a-zA-Z]+(?:/[0-9a-zA-Z#{"\303\244-\303\256"}~!@#%&./?=_+-]*)?)|u
          summary = summarize_url( $1 )
          if summary && summary !~ /Flickr is almost certainly the best/
            m.reply summary
          end
        end
      end
    end
  end
end
