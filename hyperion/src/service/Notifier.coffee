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

logger = require('../util/logger').getLogger 'service'
EventEmitter = require('events').EventEmitter

NOTIF_EVT = 'notify'

module.exports = class Notifier
  _instance = undefined
  @get: ->
    _instance ?= new _Notifier()

# The Notifier allows services to send notifications across the server and administration
# clients.
# It exposes a singleton class. The unic instance is retrieved by the `get()` method.
#
class _Notifier extends EventEmitter

  # The notification event to listen to
  NOTIFICATION: "#{NOTIF_EVT}" # performs a copy to avoid external notifications

  # Send a notification
  #
  # @param event [String] the notification name or kind
  # @param details... [Any] optional data send with notification
  notify: (event, details...) =>
    @emit.apply @, [NOTIF_EVT, event].concat details