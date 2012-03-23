require 'cgi'
require 'open-uri'
require 'nokogiri'

module Cinch
  module Plugins
    class DownForMe
      include Cinch::Plugin
      enable_acl

      match(/(?:up|down)\?? +(.+)/)
      def execute(m, site)
        doc = Nokogiri::HTML( open( "http://www.downforeveryoneorjustme.com/#{site}" ) )
        m.reply "[#{site}] " + doc.at( 'div#container' ).children.select{ |e| e.text? }.join( ' ' ).gsub( /\s+/, ' ' ).strip, true
      end
    end
  end
end
