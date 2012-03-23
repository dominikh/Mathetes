require 'ideone'

module Cinch
  module Plugins
    class Ideone
      include Cinch::Plugin
      enable_acl

      match(/(ruby|rb|rbp|python|py|perl|pl|php) (.+)/)
      def execute(m, lang, code)
        case lang
        when 'ruby', 'rb'
          lang = :ruby
        when 'rbp'
          lang = :ruby
          code = %{
              def print_wrapper__
                #{code}
              end
              print print_wrapper__.inspect
            }
        when 'python', 'py'
          lang = :python
        when 'perl', 'pl'
          lang = :perl
        when 'php'
          lang = :php
        end

        paste_id = ::Ideone.submit( lang, code )
        begin
          stdout = ::Ideone.run( paste_id, nil ).inspect
          if stdout.length > config[:max_result_length]
            stdout = stdout[ 0...config[:max_result_length] ] + "..."
          end
          m.reply "[code] #{stdout}"
        rescue ::Ideone::IdeoneError => e
          m.reply "[code] #{e.message}"
        end
      end
    end
  end
end

