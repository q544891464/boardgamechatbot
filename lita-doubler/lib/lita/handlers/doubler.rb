#---
# Excerpted from "Build Chatbot Interactions",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/dpchat for more book information.
#---
module Lita
  module Handlers
    class Doubler < Handler
      route(
        /^double\s+(\d+)$/i,
        :respond_with_double,
        command: true,
        help: { 'double N' => 'prints N + N' }
      )

      def respond_with_double(response)
        # Read up on the Ruby MatchData class for more options
        n = response.match_data.captures.first
        n = Integer(n)

        response.reply "#{n} + #{n} = #{double_number n}"
      end

      def double_number(n)
        n + n
      end

      Lita.register_handler(self)
    end
  end
end
