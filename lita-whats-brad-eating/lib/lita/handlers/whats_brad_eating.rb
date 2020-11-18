
require 'nokogiri'

module Lita
  module Handlers
    class WhatsBradEating < Handler
      route  /^what('|’)s brad eating$/i,
        :brad_eats,
        command: true,
        help: { "what's brad eating" => "latest post from brad's food tumblr" }

      # hardcode the content source URL for reuse through the module
      BLOG_URL = 'https://whatsbradeating.tumblr.com'.freeze

      # save brad's web response for reuse in building your chat response
      def response
        @_response ||= http.get(BLOG_URL)
      end

      # load in the raw text in your web response as structured markup
      #   for programmatic data extraction
      def parsed_response
        Nokogiri.parse(response.body)
      end

      # returns the first post from a stream of parsed tumblr HTML
      def first_post
        parsed_response.css('section.post').first
      end

      # isolates the HTML image tag portion of the first post
      def image
        first_post.css('.photo-wrapper img').first
      end

      # isolates the HTML image caption portion of the first post
      def caption
        image.attributes.fetch('alt')
      end

      # load up the caption and image using the methods above
      #   and send them back to the chat room
      def brad_eats(response)
        # caption text had some stray newlines we don't need
        caption_text = caption.text.strip
        img_url = image.get_attribute('src')

        msg = "#{caption_text} >> #{img_url}"

        response.reply msg
      end

      Lita.register_handler(self)
    end
  end
end
