require 'open-uri'
require 'nokogiri'

module Cinch
  module Plugins
    class WhatTheCommit
      include Cinch::Plugin
      enable_acl

      match("commit")
      def execute(m)
        open 'http://whatthecommit.com/' do |io|
          m.reply Nokogiri::HTML(io).css('#content > p').text.strip
        end
      end
    end
  end
end
