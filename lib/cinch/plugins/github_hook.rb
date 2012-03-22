# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

require 'json'
require 'open-uri'
require 'cgi'
require 'eventmachine'

module Cinch
  module Plugins
    module GitHubHookServer
      def self.bot=(bot)
        @bot = bot
      end

      def say_rev( rev, message, destination )
        @seen ||= Hash.new
        s = @seen[destination] ||= Hash.new
        if ! s[rev]
          @bot.channel_list.find_ensured(destination).safe_send(message.tr("\n", " "))
          s[rev] = true
        end
      end

      def zepto_url(url)
        URI.parse('http://z.pist0s.ca/zep/1?uri=' + CGI.escape(url)).read
      rescue
      end

      def receive_data(data)
        begin
          hash = JSON.parse(data)
        rescue JSON::ParserError
          File.open( Time.now.strftime( "github-bad-data-%Y-%m-%d-%H%M.json" ), 'w' ) { |f| f.puts data }
          raise
        end

        repo = hash[ 'repository' ][ 'name' ]
        repos = PStore.new( 'github-repos.pstore' )
        repos.transaction { @channels = repos[ repo ] }

        commits = hash[ 'commits' ]

        if commits.size < 7
          # Announce each individual commit
          commits.each do |cdata|
            author = cdata[ 'author' ][ 'name' ]
            message = cdata[ 'message' ].gsub( /\s+/, ' ' )[ 0..384 ]
            url = zepto_url( cdata[ 'url' ] )
            # FIXME escape strings
            text = "[#{Format(:bold, "github")}] [#{Format(:bold, repo)}] <#{Format(:orange, author)}> #{message} #{url}"

            if @channels.nil? || @channels.empty?
              @bot.channel_list.find_ensured("#mathetes").send "Unknown repo: '#{repo}'"
            elsif message !~ /^Merge (?:remote )?branch /
              @channels.each do |channel|
                say_rev cdata[ 'id' ], text, channel
              end
            end
          end
        else
          # Too many commits; say a summary only
          authors = commits.map { |c| c[ 'author' ][ 'name' ] }.uniq
          shas = commits.map { |c| c[ 'id' ] }
          first_url = zepto_url( commits[ 0 ][ 'url' ] )
          if @channels
            @channels.each do |channel|
              @seen ||= Hash.new
              s = ( @seen[ channel ] ||= Hash.new )
              shas.each do |sha|
                s[ sha ] = true
              end
              @bot.channel_list.find_ensured(channel).send "[#{Format(:bold, "github")}] [#{Format(:green, repo)}] #{commits.size} commits by: #{Format(:orange, authors.join( ', ' ))}  #{first_url}"
            end
          end
        end

        close_connection
      end
    end

    class GitHubHook
      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        @repos = PStore.new( "github-repos.pstore" )
        GitHubHookServer.bot = @bot
        @em_thread = Thread.new do
          loop do
            EventMachine::run do
              EventMachine::start_server '127.0.0.1', 9005, GitHubHookServer
            end
            info "*** EventMachine died; restarting ***"
          end
        end
      end

      def unregister(*args)
        @em_thread.kill
        super
      end

      match(/github (?:add|sub|subscribe) (\S+)(?: (\S+)?)$/, method: :subscribe)
      match(/github (?:delete|del|rm|remove|unsub|unsubscribe) (\S+)(?: (\S+))?$/, method: :unsubscribe)
      match(/github list (\S+)$/, method: :list)
      def subscribe(m, repository, channel = nil)
        @repos.transaction do
          @repos[repository] ||= []
          channel = (channel || m.channel.name).irc_downcase(@bot.irc.isupport["CASEMAPPING"])
          @repos[repository] << channel
          m.reply "#{channel} subscribed to github repository #{repository}."
        end
      end

      def unsubscribe(m, repository, channel = nil)
        @repos.transaction do
          channels = @repos[ repository ]
          channel = (channel || m.channel.name).irc_downcase(@bot.irc.isupport["CASEMAPPING"])
          if channels && channels.any?
            if channels.delete(channel)
              m.reply "#{channel} unsubscribed from github repository #{repository}."
            else
              m.reply "#{channel} not subscribed to github repository #{repository}?"
            end
          else
            m.reply "#{channel} not subscribed to github repository #{repository}?"
          end
        end
      end

      def list(m, target)
        @repos.transaction do
          r = @repos[target]
          if r
            m.reply r.join(' ')
          else
            repos = []
            @repos.roots.each do |k|
              if @repos[k].include?(target)
                repos << @repos[k]
              end
            end

            if repos.any?
              m.reply repos.map { |rr| rr[0] }.join(', ')
            else
              m.reply "No github hook subscriptions found."
            end
          end
        end
      end
    end
  end
end

