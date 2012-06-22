###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###
'use strict'

winston = require 'winston'
util = require './utils'

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
            level: util.confKey "logLevels.#{name}", 'info' # read from configuration file
            colorize: 'true'
        ]

    # and returns it
    loggers[name]