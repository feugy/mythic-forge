logger = require('../logger').getLogger 'model'
EventEmitter = require('events').EventEmitter

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
  # @param instance [Object] the Mongoose document that was modified
  # @param modified [Array<String>] array of modified path of the instance
  change: (operation, instance, modified) =>
    parameter = {}
    parameter[key] = value for own key,value of instance._doc
    if operation is 'update'
      # for update, only emit modified datas
      parameter = 
        _id: instance._id
        type: instance.type?._id
      parameter[path] = instance.get path for path in modified
    else if operation is 'creation' or 'deletion'
      parameter.type = parameter.type?._id
    else 
      throw new Error "Unknown operation #{operation} on instance #{parameter._id}"

    logger.debug "change propagation: #{operation} of instance #{parameter._id}"
    @emit 'change', operation, parameter

class ModelWatcher
  _instance = undefined
  @get: ->
    _instance ?= new _ModelWatcher()

module.exports = ModelWatcher