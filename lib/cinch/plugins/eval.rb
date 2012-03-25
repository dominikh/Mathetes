# -*- coding: utf-8 -*-
module Cinch
  module Plugins
    class Eval
      include Cinch::Plugin
      enable_acl

      match(/eval (.+)/)
      def execute(m, string)
        begin
          ret = eval(string).inspect
          if ret.size > 400
            ret = ret[0, 400] + "…"
          end

          m.reply ret
        rescue Exception => e
          m.reply "Exception: #{e.message}"
        end
      end
    end
  end
end
