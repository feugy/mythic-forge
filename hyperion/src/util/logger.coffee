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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

'use strict'

moment = require 'moment'
_ = require 'underscore'
_s = require 'underscore.string'
fs = require 'fs-extra'
pathUtils = require 'path'
utils = require '../util/common'
EventEmitter = require('events').EventEmitter

conf = null
dateFormat = null
nameMaxLength = null
levelMaxLength = 5
output = null
# logger cache
loggers = {}
# possible methods, with their verbosity. 0 means all logs.
methods =
  all: 0
  trace: 1
  log: 2
  debug: 2
  info: 3
  warn: 4
  error : 5
  off: 6

# Exports an event emitter
emitter = new EventEmitter()
emitter.setMaxListeners 0

# init configuration dependent variables
init = ->
  conf = utils.confKey 'logger'
  dateFormat = conf.dateFormat or 'YYYYMMDDHHmmss'
  nameMaxLength = conf.nameMaxLength or 24

  # Initialize condiguration
  conf.levels = conf.levels or {}

  # enforce file existence
  if conf.path isnt 'console'
    isConsole = false
    fs.mkdirsSync pathUtils.dirname conf.path 
    fs.writeFileSync conf.path, '' unless !fs.existsSync conf.path
    # opens file stream
    output = fs.createWriteStream conf.path, flags: 'a', encodinf: 'utf8'
  else
    output = process.stdout;
    isConsole = true

  # process.stdout.write ">>> configure log to output #{conf.path}\n"
    
# on configuration change, reinit
utils.on 'confChanged', ->
  init()
  # compute again all logger's level
  logger._level = computeLevel name for name, logger of loggers

init()

# Compute the logger level, regarding configuration and logger's name
#
# @param name [String] logger's name.
# @return the number corresponding to the level, or equivalent to 'off' level if not found.
computeLevel = (name) ->
  op = conf.defaultLevel;
  op = conf.levels[name] if name of conf.levels
  if op of methods then methods[op] else methods.off

# Format a message
#
# @param args [Array] original arguments of the invoked logger method
# @param level [String] logger method's level
# @param name [String] logger's name
# @return the formated string message.
# @throw an error if name is above 24 characters
# @throw an error if parameter is above 25 characters
format = (args, level, name) ->
  # date name level parameter : message
  vals = (if _.isObject arg then JSON.stringify arg else arg?.toString() for arg in args)
  "#{moment().format conf.dateFormat or defaultDateFormat} #{process.pid} #{_s.pad name, nameMaxLength} #{_s.pad level, levelMaxLength} : #{vals.join ' '}"

# Logger Factory: creates new (or retrieve existing) logger with the following methods (ordered):
#  trace, log, debug, info, warn, error
#
# All those methods can be invoked with any number of arguments, which are turned into strings and concatenated.
#
# Logger output goes to a file or to stdout, with a given format:
#   date + ' ' + name + ' ' + level + ' : ' + message
#
# - date: formated date (YYYYMMDD_HHmmss)
# - pid: process id
# - name: logger's name (right-padded to 15 characters)
# - level: method's level (right-padded to 5 characters)
# - message: method's arguments, joined with white space
#
# All Logger's output goes to the same output, configured in the global configuration.
# Each logger level can be set in global configuration : 
# {
#   logger: {
#     defaultLevel: 'debug',
#     nameMaxLength: 20,
#     dateFormat: 'YYYY-MM-DDTHH:mm:ss'
#     levels: {
#       x: 'all',
#       y: 'warn',
#       z: 'off'
#     },
#     path: 'console'
#   },
# }
#
# @param name [String] name of the logger. Must be at most 24 characters long (error raised).
# @param parameter [String] the logger's custom parameter (optionnal). Must be at most 25 characters long (error raised).
# @return the created logger.
emitter.getLogger = (name) ->
  unless name of loggers
    throw new Error 'logger name is mandatory' unless name
    throw new Error "logger with name #{name} exceeds the maximum length of #{nameMaxLength}" unless name.length <= nameMaxLength

    # logger level, default to off
    logger = 
      _level: computeLevel name
      _name: name

    for op of methods when op isnt 'all' and op isnt 'off'
      # add the operation methods
      logger[op] = ((opName) ->
        ->
          args = Array::slice.call arguments
          # only level allows it
          if methods[opName] >= @_level
            output.write "#{format args, opName, @_name}\n"
            emitter.emit 'log', level: opName, name: @_name, args: args
      )(op)

    loggers[name] = logger

  loggers[name]

# Erase standard console methods
unless process.env?.NODE_ENV is 'test'
  shim = emitter.getLogger 'console'
  console[op] = method for op, method of shim
  console.dir = console.log

module.exports = emitter