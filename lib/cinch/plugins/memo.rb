require "yaml"

# TODO use the storage API when available
module Cinch
  module Plugins
    class Memo
      Memo = Struct.new(:message, :recipient, :sender, :time)
      include Cinch::Plugin
      enable_acl

      match(/memo ([\S]+) (.+)/)
      listen_to :message, method: :on_message
      listen_to :join, method: :on_join

      def initialize(*args)
        super
        @db = PStore.new('memos.pstore')
      end

      def execute(m, recipient, message)
        if recipient =~ %r{^/(.*)/$}
          recipient = Regexp.new(recipient[1..-2])
          m.reply "Memo recorded for /#{recipient.source}/.", true
        else
          if memos_for(recipient).size >= config[:max_per_person]
            m.reply "The inbox of #{recipient} is full."
            return
          end
          m.reply "Memo recorded for #{recipient}.", true
        end
        memo = Memo.new(message, recipient, m.user.nick, m.time)
        @db.transaction do
          @db[recipient] ||= []
          @db[recipient] << memo
        end
      end

      def on_message(m)
        return  if config[:ignore].include?( m.user.nick )

        memos = memos_for( m.user.nick )
        if memos.size <= config[:public_reading_threshold] && m.channel?
          dest = m.channel
        else
          dest = m.user
        end

        memos.values.flatten.each do |memo|
          age = humanize_seconds((::Time.now - memo.time).round)
          dest.send "#{m.user.nick}: [#{age} ago] <#{memo.sender}> #{memo.message}"
        end

        @db.transaction do
          memos.keys.each do |key|
            @db.delete(key)
          end
        end

        save_db
      end

      def on_join(m)
        return  if config[:ignore].include?( m.user.nick )

        memos = memos_for( m.user.nick )
        if memos.size > 0
          m.user.send "You have #{memos.size} memo(s).  Speak publicly in a channel to retrieve them."
        end
      end

      private
      # @param [String] recipient
      # @return [Hash{String, Regexp => Array<Memo>}]
      def memos_for(recipient)
        @db.select { |key, value|
          case key
          when Regexp
            recipient =~ key
          else
            recipient == key
          end
        }
      end

      # @param [Integer] secs
      # @return [String]
      def humanize_seconds(secs)
        [[60, "s"], [60, "m"], [24, "h"], [1000, "d"]].map{ |count, name|
          if secs > 0
            secs, n = secs.divmod(count)
            "#{n.to_i}#{name}"
          end
        }.compact.reverse.join(' ')
      end
    end
  end
end
