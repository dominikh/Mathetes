module Cinch
  module Plugins
    class Eval
      include Cinch::Plugin
      enable_acl

      match(/eval (.+)/)
      def execute(m, string)
        ret = eval(string)
        m.reply ret.inspect
      end
    end
  end
end
