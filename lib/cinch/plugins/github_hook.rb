# This listens for connections from the github-hook server,
# which is running independently, receiving POSTs from github.com.

# By Pistos - irc.freenode.net#mathetes

require 'json'
require 'open-uri'
require 'cgi'
require 'sinatra/base'

module Cinch
  module Plugins
    class GitHubHook
      class Server < Sinatra::Base
        set :port, 9005
        set :environment, "production"
        set :logging, nil
        def self.bot
          @bot
        end

        def self.bot=(bot)
          @bot = bot
        end

        post '/' do
          self.class.bot.loggers.debug "Receiving JSON payload"
          self.class.bot.handlers.dispatch(:github_hook, nil, params[:payload])
          ""
        end
      end

      include Cinch::Plugin
      enable_acl

      def initialize(*args)
        super

        @seen = {}
        @repos = PStore.new( "github-repos.pstore" )
        @sinatra_thread = Thread.new do
          Server.bot = @bot
          Server.run!
        end
      end

      def unregister(*args)
        @sinatra_thread.kill
        super
      end

      match(/github (?:add|sub|subscribe) (\S+)(?: (\S+))?$/, method: :subscribe)
      match(/github (?:delete|del|rm|remove|unsub|unsubscribe) (\S+)(?: (\S+))?$/, method: :unsubscribe)
      match(/github list (\S+)$/, method: :list)
      listen_to :github_hook, method: :github_hook
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

      def github_hook(m, payload)
        hash = JSON.parse(payload)
        repo = hash['repository']['name']
        repos = PStore.new('github-repos.pstore')
        channels = nil
        repos.transaction { channels = repos[repo] || [] }
        channels.map! {|c| Channel(c)}


        commits = hash['commits']

        if commits.size < 7
          # Announce each individual commit
          commits.each do |cdata|
            author  = cdata['author']['name']
            message = cdata['message'].gsub(/\s+/, ' ')[0..384]
            url     = cdata['url']
            # FIXME escape strings
            text = "[#{Format(:bold, "github")}] [#{Format(:bold, repo)}] <#{Format(:orange, author)}> #{message} #{url}"

            if channels.nil? || channels.empty?
              Channel("#dominikh").send "Unknown repo: '#{repo}'"
            elsif message !~ /^Merge (?:remote )?branch /
              channels.each do |channel|
                say_rev cdata['id'], text, channel
              end
            end
          end
        else
          # Too many commits; say a summary only
          authors = commits.map { |c| c['author']['name'] }.uniq
          shas = commits.map { |c| c['id'] }
          first_url = commits[0]['url']
          if channels
            channels.each do |channel|
              shas.each do |sha|
                mark_as_seen(sha, channel)
                @seen[sha] = true
              end
              channel.send "[#{Format(:bold, "github")}] [#{Format(:green, repo)}] #{commits.size} commits by: #{Format(:orange, authors.join( ', ' ))}  #{first_url}"
            end
          end
        end
      end

      private
      def mark_as_seen(rev, where)
        (@seen[where] ||= {})[rev] = true
      end

      def seen?(rev, where)
        (@seen[where] ||= {})[rev]
      end

      def say_rev(rev, message, destination)
        if !seen?(rev, destination)
          destination.send(message.gsub("\n", ' '))
          mark_as_seen(rev, destination)
        end
      end
    end
  end
end

