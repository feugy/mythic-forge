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

_ = require 'underscore'
pathUtils = require 'path'
utils = require '../utils'
logger = require('../logger').getLogger 'model'
EventEmitter = require('events').EventEmitter

gameClientRoot = utils.confKey 'game.dev'

# The ModelWatcher track model modifications.
# It exposes a singleton class. The unic instance is retrieved by the `get()` method.
#
class _ModelWatcher extends EventEmitter

  # Method invoked when an instance has created, modified or removed
  #
  # Will trigger an event "change" with as first parameter the operation name,
  # and as second the changed instance. 
  # 
  # For creation and deletion, the whole instance is passed to the event, minus the
  # type which is replaced by its _id.
  # For update, only the _id, type's _id and modified fields are propagated.
  #
  # @param operation [String] one of "creation", "update" or "deletion"
  # @param className [String] classname of the modified instance
  # @param instance [Object] the Mongoose document that was modified
  # @param modified [Array<String>] array of modified path of the instance
  change: (operation, className, instance, modified) =>
    changes = {}
    if '_doc' of instance
      changes[key] = value for own key,value of instance._doc
    else 
      changes = _.clone instance

    delete changes.__v # added by mongoose to store version

    # do not embed the linked map and type for items, events and fields
    changes.type = changes.type?._id if className is 'Item' or className is 'Event'

    if modified and 'map' in modified and (className is 'Item' or className is 'Field')
      # but send the map if it changed
      changes.map = changes.map?._id if 'object' is utils.type changes.map and changes.map._id

    if operation is 'update'
      if className isnt 'Executable' and className isnt 'FSItem'
        # for update, only emit modified datas
        changes = 
          _id: instance._id
        changes[path] = instance.get path for path in modified

    else if operation isnt 'creation' and operation isnt 'deletion'
      throw new Error "Unknown operation #{operation} on instance #{changes._id or changes.path}}"

    # Specific case of FSItem that must be relative to gameClient root
    changes.path = pathUtils.relative gameClientRoot, changes.path if className is 'FSItem'

    # Do not propagate password nor tokens of Players
    if className is 'Player'
      require('../model/Player').purge changes
      return if Object.keys(changes).length is 0

    logger.debug "change propagation: #{operation} of instance #{changes._id or changes.path} (#{className})"
    @emit 'change', operation, className, changes

class ModelWatcher
  _instance = undefined
  @get: ->
    _instance ?= new _ModelWatcher()

module.exports = ModelWatcher