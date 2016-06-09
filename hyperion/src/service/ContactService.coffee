###
  Copyright 2010~2014 Damien Feugas

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

_ = require 'lodash'
async = require 'async'
Mailgun = require 'mailgun-js'
isEmail = require 'isemail'
logger = require('../util/logger').getLogger 'service'
utils = require '../util/common'

# Singleton instance
_instance = undefined
module.exports = class ContactService

  @get: ->
    _instance ?= new _ContactService()

# The ContactService allows rule to send notification to players, through emails or other means,
# depending on player preferences and providers
#
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _ContactService

  printModule: => [module.parent?.filename, module.parent?.id]

  # **private**
  # Wrapper around Mailgun API to send mails
  _mailer: null

  # **private**
  # Sender that will appears in email sent
  _sender: null

  # **private**
  # Settings used for underscore's template
  _templateSettings:
    # use coffee instead of ERB delimiter
    interpolate: /#{(.+?)}/g
    evaluate: /#{(.+?)}/g
    # used to referenciate data within template
    variable: 'player'

  # Service constructor.
  constructor: ->
    @_init()
    utils.on 'confChanged', @_init

  # **private**
  # Initialize the mailer wrapper with provided api key and domain
  _init: =>
    @_sender = utils.confKey 'mailgun.sender'
    @_mailer = new Mailgun
      apiKey: utils.confKey 'mailgun.key'
      domain: utils.confKey 'mailgun.domain'

  # **private**
  # Separate subject (first line) from body (other lines)
  # Performs replacement to personalize email.
  # Templating is done with _.template
  # Fails if body is empty, or contains only blank characters
  #
  # @param player [Player] player to which message is sent
  # @param template [Function] underscore precompiled template that will create the message
  # @param callback [Function] end callback, invoked with arguments
  # @option callback err [Error] error object. Null if no error occured
  # @option callback data [Object] data object passed to mailgun, with subject and text/html properties
  # from and to properties will be set by ContactService
  _makeMail: (player, template, callback) =>
    message = template(player)
    # use first line to distinguish subject from body
    bk = message.indexOf '\n'
    html = message[bk+1..]
    # check body presence
    return callback new Error "body cannot be empty" if html.trim().length is 0

    callback null,
      # allow empty subject rather than fails
      subject: if bk > 0 then message[0...bk] else ''
      html: html

  # Send a message to a bunch of players
  # Message can contain placeholders, delimited with Coffee's string interpolation marker.
  # Placeholders are relative to current player
  # First line (until '\n') is used as summary (subject for emails)
  # Ex:
  #    [Game] vistory !\n<p>Congratulation #{player.firstName}, you won the game !</p>
  #
  # @param players [Player|Array<Player>] players to send message to
  # @param message [String] message to be send, with placeholders
  # @param callback [Function] end callback, invoked when all message were sent, with parameters:
  # @option callback err [Error] an error object. Null if no error occured
  # @option callback report [Array<Object>] a report containing sending result for each player
  sendTo: (players, message, callback) =>
    return if utils.fromRule callback
    # make player an array if not alreay the case
    players = [players] unless Array.isArray players

    report = []
    # compile template once for all
    template = _.template message, @_templateSettings

    # asynchronously send email to single players
    async.each players, (player, next) =>
      # prepare common utilities
      endpoint = player.email
      operation =
        success: false
        kind: 'email'
        endpoint: endpoint

      # check email format and domain existence
      isEmail.validate endpoint, {checkDNS: true, errorLevel: true}, (valid) =>
        unless valid is 0
          logger.log "cannot send email to #{endpoint} due to lack of usable email"
          operation.err = new Error if valid in [5, 6] then "unexistent domain in email #{endpoint}" else "invalid email #{endpoint}"
          report.push operation
          return next()

        # performs replacements
        @_makeMail player, template, (err, data) =>
          if err?
            operation.err = err
            report.push operation
            return next()

          # set start and end points data before sending the mail
          data.from = @_sender
          data.to = endpoint
          @_mailer.messages().send data, (err, result) =>
            if err?
              operation.err = err
            else
              operation.success = true

            logger.log "sent email to #{endpoint}:", operation.err or 'success !'
            # keep report
            report.push operation
            next()

    , (err) =>
      # send back all report
      callback err, report