require 'm4dbi'

module Mathetes
  module Plugins
    class MemoManager
      include Cinch::Plugin

      # Add bot names to this list, if you like.
      # TODO put this into a config
      IGNORED = [
                 "",
                 "*",
                 "Gherkins",
                 "Mathetes",
                 "GeoBot",
                 "scry",
                ]

      # TODO put this into a config
      MAX_MEMOS_PER_PERSON = 20
      # TODO put this into a config
      PUBLIC_READING_THRESHOLD = 2

      def initialize(*args)
        super
        # TODO config
        @dbh = DBI.connect( "DBI:Pg:reby-memo:localhost", "memo", "memo" )
      end

      match(/memo ([\S]+) (.+)/)
      listen_to :message, method: :on_message
      listen_to :join, method: :on_join

      def execute(m, recipient, message)
        if recipient =~ %r{^/(.*)/$}
          recipient_regexp = Regexp.new $1
          @dbh.do(
                  "INSERT INTO memos ( sender, recipient_regexp, message ) VALUES ( ?, ?, ? )",
                  m.user.nick,
                  recipient_regexp.source,
                  message
                  )
          m.reply "Memo recorded for /#{recipient_regexp.source}/.", true
        else
          if memos_for( recipient ).size >= MAX_MEMOS_PER_PERSON
            m.reply "The inbox of #{recipient} is full."
          else
            @dbh.do(
                    "INSERT INTO memos ( sender, recipient, message ) VALUES ( ?, ?, ? )",
                    m.user.nick,
                    recipient,
                    message
                    )
            m.reply "Memo recorded for #{recipient}.", true
          end
        end
      end

      def on_message(m)
        return  if IGNORED.include?( m.user.nick )

        memos = memos_for( m.user.nick )
        if memos.size <= PUBLIC_READING_THRESHOLD && m.channel?
          dest = m.channel
        else
          dest = m.user
        end

        memos.each do |memo|
          age = memo[ 'sent_age' ].gsub( /\.\d+$/, '' )
          case age
          when /^00:00:(\d+)/
            age = "#{$1} seconds"
          when /^00:(\d+):(\d+)/
            age = "#{$1}m #{$2}s"
          else
            age.gsub( /^(.*)(\d+):(\d+):(\d+)/, "\\1 \\2h \\3m \\4s" )
          end
          dest.send "#{m.user.nick}: [#{age} ago] <#{memo['sender']}> #{memo['message']}"

          @dbh.do(
                  "UPDATE memos SET time_told = NOW() WHERE id = ?",
                  memo[ 'id' ]
                  )
        end
      end

      def on_join(m)
        return  if IGNORED.include?( m.user.nick )

        memos = memos_for( m.user.nick )
        if memos.size > 0
          m.user.send "You have #{memos.size} memo(s).  Speak publicly in a channel to retrieve them."
        end
      end

      def memos_for( recipient )
        @dbh.select_all(
                        %{
          SELECT
            m.*,
            age( NOW(), m.time_sent )::TEXT AS sent_age
          FROM
            memos m
          WHERE
            (
              lower( m.recipient ) = lower( ? )
              OR ? ~* m.recipient_regexp
            )
            AND m.time_told IS NULL
        },
                        recipient,
                        recipient
                        )
      end
    end
  end
end
