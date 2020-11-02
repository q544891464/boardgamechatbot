#---
# Excerpted from "Build Chatbot Interactions",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/dpchat for more book information.
#---
Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = 'BookBot'

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.

  if ENV['RACK_ENV'] == 'production'
    config.robot.adapter = :slack
    config.redis[:url] = ENV.fetch('REDIS_URL')
  else
    config.robot.adapter = :shell
  end

  # slack adapter demands a value even in dev when we aren't using it...
  config.adapters.slack.token = ENV.fetch('SLACK_TOKEN', '')

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "myname"
  # config.adapter.password = "secret"

  ## Example: Set options for the Redis connection.
  # config.redis.host = "127.0.0.1"
  # config.redis.port = 1234

  config.http.port = ENV.fetch('PORT', '8080')

  Lita::Handlers::ImgflipMemes.add_meme(
    template_id: 61546,
    pattern: /(brace yoursel[^\s]+) (.*)/i,
    help: 'brace yourselves, <text>')

  config.handlers.travis_announcer.travis_room = '#general'

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"
end
