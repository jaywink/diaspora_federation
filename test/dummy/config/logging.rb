Logging::Rails.configure do |config|
  # Configure the Logging framework with the default log levels
  Logging.init %w(debug info warn error fatal)

  # Objects will be converted to strings using the :inspect method.
  Logging.format_as :inspect

  # The default layout used by the appenders.
  pattern = "[%d] %-5l PID-%p TID-%t %c: %m\n"
  layout = Logging.layouts.pattern(pattern: pattern)

  # Setup a color scheme called 'bright' than can be used to add color codes
  # to the pattern layout. Color schemes should only be used with appenders
  # that write to STDOUT or STDERR; inserting terminal color codes into a file
  # is generally considered bad form.
  Logging.color_scheme("bright",
                       levels:  {
                         info:  :green,
                         warn:  :yellow,
                         error: :red,
                         fatal: %i(white on_red)
                       },
                       date:    :blue,
                       logger:  :cyan,
                       message: :magenta
                      )

  # Configure an appender that will write log events to STDOUT. A colorized
  # pattern layout is used to format the log events into strings before
  # writing.
  Logging.appenders.stdout("stdout",
                           auto_flushing: true,
                           layout:        Logging.layouts.pattern(
                             pattern:      pattern,
                             color_scheme: "bright"
                           )
                          ) if config.log_to.include? "stdout"

  # Configure an appender that will write log events to a file. The file will
  # be rolled on a daily basis, and the past 7 rolled files will be kept.
  # Older files will be deleted. The default pattern layout is used when
  # formatting log events into strings.
  Logging.appenders.rolling_file("file",
                                 filename:      config.paths["log"].first,
                                 keep:          7,
                                 age:           "daily",
                                 truncate:      false,
                                 auto_flushing: true,
                                 layout:        layout
                                ) if config.log_to.include? "file"

  # Setup the root logger with the Rails log level and the desired set of
  # appenders. The list of appenders to use should be set in the environment
  # specific configuration file.
  #
  # For example, in a production application you would not want to log to
  # STDOUT, but you would want to send an email for "error" and "fatal"
  # messages:
  #
  # => config/environments/production.rb
  #
  #     config.log_to = %w[file email]
  #
  # In development you would want to log to STDOUT and possibly to a file:
  #
  # => config/environments/development.rb
  #
  #     config.log_to = %w[stdout file]
  #
  Logging.logger.root.appenders = config.log_to unless config.log_to.empty?

  # Default log-level (development=debug, production=info)
  Logging.logger.root.level = config.log_level

  # log-levels for SQL and federation debug-logging
  Logging.logger[ActiveRecord::Base].level = :debug
  Logging.logger["XMLLogger"].level = :debug
end
