module Cinch
  module Plugins
    class Sample
      include Cinch::Plugin

      match(/foo\b/)
      def execute(m)
        m.reply "Foo to you!"
      end
    end
  end
end
