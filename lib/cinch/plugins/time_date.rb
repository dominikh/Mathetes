require 'time'

module Cinch
  module Plugins
    class TimeDate
      include Cinch::Plugin
      enable_acl

      match(/time(?: (\w{1,3})([+-]\d{1,2})?)?/)
      def execute(m, timezone, adjustment)
        timezone ||= config[:default_timezone]
        adjustment = adjustment.to_i * 3600

        time = Time.at(Time.now.utc + Time.zone_offset(timezone) + adjustment)

        timezone_string = timezone
        if adjustment > 0
          timezone_string += "+" + adjustment.to_s
        elsif adjustment < 0
          timezone_string += adjustment.to_s
        end

        m.reply(time.strftime(config[:format].gsub("%Z", timezone_string)))
      end
    end
  end
end

