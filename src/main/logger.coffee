winston = require 'winston'

levels = 
  debug: 0
  info: 1
  warn: 2
  error: 3

colors =
  debug: 'grey'
  info: 'green'
  warn: 'orange'
  error: 'red'

loggers = {}

module.exports =

  # Instantiate (or returns existing) a logger.
  # 
  # @param name [String] the logger name.
  # @returns the logger for the calling module.
  getLogger: (name) ->
    # if the category does not exists yet 
    if not (name of loggers)
      console.info "create logger for #{name}"
      # creates if
      loggers[name] = new winston.Logger
        padLevels: true
        levels: levels
        colors: colors
        transports: [ 
          new winston.transports.Console 
            padLevels: true
            level: 'warn' # TODO read configuration on a file ?
            colorize: 'true'
        ]

    # and returns it
    loggers[name]