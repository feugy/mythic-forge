logger = require('../logger').getLogger 'model'
EventEmitter = require('events').EventEmitter

# The ModelWatcher track model modifications.
# It exposes a singleton class. The unic instance is retrieved by the `get()` method.
#
class _ModelWatcher extends EventEmitter

  # Method invoked when an instance has created, modified or removed
  #
  # @param operation [String] one of "create", "save" or "remove"
  # @param instance [Object] the Mongoose document that was modified
  # @param modified [Array<String>] array of modified path of the instance
  change: (operation, instance, modified) =>
    switch operation
      when 'create'
        logger.debug "creation of instance #{instance._id}"
        @emit "created", instance
      when 'save'
        # for update, only emit modified datas
        modifications = 
          _id: instance._id
          type: instance.get 'type'
        modifications[path] = instance.get path for path in modified
        logger.debug "update of instance #{instance._id}"
        @emit "updated", modifications
      when 'remove' 
        logger.debug "removal of instance #{instance._id}"
        @emit "removed", instance
      else throw new Error "Unknown operation #{operation} on instance #{instance._id}"

class ModelWatcher
  _instance = undefined
  @get: ->
    _instance ?= new _ModelWatcher()

module.exports = ModelWatcher