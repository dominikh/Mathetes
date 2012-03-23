module Cinch
  module Plugins
    class Spell
      ValidLanguages = %w[en de fr pt es it]
      include Cinch::Plugin
      enable_acl

      match(/spell (?:([\S]+) )?(.+)/)
      def execute(m, lang, word)
        unless ValidLanguages.include?(lang)
          lang = "en"
        end

        if word.length > config[:max_word_length]
          retval = "That's not a real word!  :P"
        else
          word.gsub!( /[^a-zA-Z'-]/, '' )
          aspell = `echo '#{word.gsub("'", "'\\\\''")}' | aspell -d '#{lang}' -a --sug-mode=bad-spellers`

          list = aspell.split( ':' )
          result = list[ 0 ]

          if result =~ /\*$/
            retval = "#{word} is spelled correctly."
          else
            if list[ 1 ]
              words = list[ 1 ].strip.split( "," )
              retval = "'#{word}' is probably one of: #{words[ 0, config[:num_suggestions] ].join( ',' )}"
            else
              retval = "No suggestions for unknown word '#{word}'."
            end
          end
        end

        m.reply retval
      end
    end
  end
end
