define [
  'backbone',
  'model/sockets'
], (Backbone, sockets) ->

  # Client cache of fields.
  # Wired to the server through socket.io
  class Fields extends Backbone.Collection

    constructor: (@model, @options) ->
      super model, options
      # connect server response callbacks
      sockets.updates.on 'update', @_onUpdate

    # Provide a custom sync method to wire Maps to the server.
    # Not implemented
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, instance, args) => 
      throw new Error "Unsupported #{method} operation on Fields"

    # **private**
    # Callback invoked when a database update is received.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given field.
    _onUpdate: (className, changes) =>
      return unless className is 'Field'
      # first, get the cached field and quit if not found
      field = @get changes._id
      return unless field?
      # then, update the local cache.
      for key, value of changes
        field.set key, value if key isnt '_id'
      # emit a change.
      @trigger 'update', field


    # Override of the inherited method to disabled default behaviour.
    # DO NOT reset anything on fetch.
    reset: =>


  # Modelisation of a single Field.
  # Not wired to the server : use collections Fields instead
  class Field extends Backbone.Model

    # field local cache.
    # A Backbone.Collection subclass that handle Fields retrieval with `fetch()`
    @collection = new Fields @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Field constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current field is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Field