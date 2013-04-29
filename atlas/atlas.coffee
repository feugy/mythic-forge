( ->

  # Atlas library has some dependencies:
  # 
  # - async@0.2.7
  # - jquery@2.0.0
  # - socket.io@0.9.10
  # - underscore@1.4.4
  #
  # Atlas needs an event bus to propagate changes on models
  # This event bus may be passed as argument of the factory, and must contain the following methods
  #
  # - emit: [Function] creates an event. Invoked with event type as first parameter, and event arguments as other parameters.
  # - on: [function] bind a listener to an event. Invoked with the event type as first parameter, and listener as second.
  # - off: [Function] removes a listener event. Invoked with the event type as first parameter, and listener as second.
  # If listener is ommited, all listeners of this event are removed. 
  # If event type is ommited, all listeners of all events are removed
  #
  # The following events will be emitted:
  #
  # - connected
  # When the player is connected.
  # @param player [Player] the connected player model
  #
  # - modelChanged
  # When a model creation, update or deletion is received. 
  # Local cache object are immediately updated, right before the event it triggered.
  # @param operation [String] operation kind: 'creation', 'update' or 'deletion'
  # @param model [Object] concerned model
  # @param changes [Array<String>] for updates, a list of properties that have been updated
  # 
  # The factory accepts a options parameter, that may include:
  # - debug [Boolean] true to ouput debug message on console.
  @factory = (eventEmitter, options = {}) ->

    # Atlas global namespace
    Atlas = 
      # socket.io high level object
      socket: null

      # socket.io namespace for incoming updates
      updateNS: null
      
      # socket.io namespace for sending messages to server
      gameNS: null
      
    #-----------------------------------------------------------------------------
    # Utilities

    classToType = {}
    for name in 'Boolean Number String Function Array Date RegExp Undefined Null'.split ' '
      classToType["[object " + name + "]"] = name.toLowerCase()
      
    # Util namespace embed commonly used function
    utils = Atlas.utils =
      
      # This method is intended to replace the broken typeof() Javascript operator.
      #
      # @param obj [Object] any check object
      # @return the string representation of the object type. One of the following:
      # object, boolean, number, string, function, array, date, regexp, undefined, null
      #
      # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
      type: (obj) ->
        strType = Object::toString.call obj
        classToType[strType] or "object"
      
      # isA() is an utility method that check if an object belongs to a certain class, or to one 
      # of it's subclasses. Uses the classes names to performs the test.
      #
      # @param obj [Object] the object which is tested
      # @param clazz [Class] the class against which the object is tested
      # @return true if this object is a the specified class, or one of its subclasses. false otherwise
      isA: (obj, clazz) ->
        return false if not (obj? and clazz?)
        currentClass = obj.constructor
        while currentClass?
          return true  if currentClass.name == clazz.name
          currentClass = currentClass.__super__?.constructor
        false
        
      # Generate a unic id for request
      # @return a generated id
      rid: -> 
        id = "#{Math.floor Math.random()*10000}"
        "req#{('0' for i in [0..5-id.length]).join()}#{id}"
      
    #-----------------------------------------------------------------------------
    # Connection to server
    
    # internal state
    isLoggingOut = false
    connected = false
    connecting = false
      
    # Needed on firefox to avoid errors when refreshing the page
    if $? and window?
      $(window).on 'beforeunload', () ->
        isLoggingOut = true
        undefined
      
    # Tries to connect with server. 
    # The current player will be identified and stored.
    # You must use this function with the authentication token obtained after sending
    # the player on the `http://host:port/api/auth/xxx` server API.
    # 
    # @param token [String] the autorization token, obtained during authentication
    # @param callback [Function] invoked when player is connected, with arguments
    # @option callback err [Error] the error object, or null if no error occured 
    # @option callback token [String] the autorization token used
    Atlas.connect = (token, callback) =>    
      isLoggingOut = false
      connecting = true
      connected = false
        
      Atlas.socket = io.connect conf.apiBaseUrl+'/', 
        query:"token=#{token}"
        'force new connection': true

      Atlas.socket.on 'close', => console.log "connect_failed", arguments

      Atlas.socket.on 'error', (err) =>
        if connecting or connected
          connected = false
          connecting = false
          Atlas.socket = null
          callback new Error err

      Atlas.socket.on 'disconnect', (reason) =>
        connecting = false
        connected = false
        Atlas.gameNS?.removeAllListeners()
        Atlas.updateNS?.removeAllListeners()
        Atlas.socket = null
        return if isLoggingOut
        callback new Error if reason is 'booted' then 'kicked' else 'disconnected'
    
      Atlas.socket.on 'connect', => 
        raw = null
        # in parallel, get connected user and wired namespaces
        async.parallel [
          (end) =>
            # On connection, retrieve current connected player immediately
            Atlas.socket.emit 'getConnected', (err, result) =>
              return end err if err?
              raw = result
              # update socket.io query to allow reconnection with new token value
              Atlas.socket.socket.options.query = "token=#{raw.token}"
              end()
          (end) ->
            # wired both namespaces
            async.forEach [
              {attr:'gameNS', ns:'game'}
              {attr:'updateNS', ns:'updates'}
            ], (spec, next) ->
              Atlas[spec.attr] = Atlas.socket.of "/#{spec.ns}"
              Atlas[spec.attr].on 'connect', next
              Atlas[spec.attr].on 'connect_failed', next
            , end
        ], (err) ->
          connecting = false
          connected = !err?
          return callback err if err?
          # enrich player before sending him
          player = new Atlas.Player raw, (err) ->
            eventEmitter.emit 'connected', player
            callback err, player
        
    # Disconnect current player from server 
    # 
    # @param callback [Function] invoked when player is properly disconnected.
    Atlas.disconnect = (callback) =>
      return callback() unless Atlas.socket?
      isLoggingOut = true
      Atlas.socket.emit 'logout'
      Atlas.socket.disconnect()
      callback()

    #-----------------------------------------------------------------------------
    # Abstract models

    # Per-class model caches
    models =
      Player: {}
      Item: {}
      ItemType: {}
      Event: {}
      EventType: {}
      Map: {}
      FieldType: {}

    # bounds to server updates
    eventEmitter.on 'connected', ->
      Atlas.updateNS.on 'creation', onModelCreation
      Atlas.updateNS.on 'update', onModelUpdate
      Atlas.updateNS.on 'deletion', onModelDeletion

    # Add the created model into relevant cache
    #
    # @param className [String] created model class name
    # @param model [Object] raw created model
    # @param  callback [Function] construction end callback, invoked with argument:
    # @option callback error [Error] an Error object, or null if no error occured
    onModelCreation = (className, model, callback = ->) ->
      return callback null unless className is 'Field' or className of models
      # build a new model
      options.debug and console.log "create new instance #{className} #{model.id}"
      new Atlas[className] model, (err, model) ->
        # manually send event for new fields
        eventEmitter.emit 'modelChanged', 'creation', model if className is 'Field' and !err?
        callback err

    # Update cached model with incoming changes
    # May enrich players new characters
    #
    # @param className [String] updated model class name
    # @param changes [Object] raw new values (always contains id)
    # @param  callback [Function] construction end callback, invoked with argument:
    # @option callback error [Error] an Error object, or null if no error occured
    onModelUpdate = (className, changes, callback = ->) ->
      return callback null unless className of models
      # first, get the cached model and quit if not found
      Atlas[className].findById changes?.id, (err, model) ->
        return callback err if err?
        return callback null unless model?
        options.debug and console.log "process update for model #{model.id} (#{className})", changes
        # then, update the local cache
        modified = false
        for attr, value of changes
          unless attr in Atlas[className]._notUpdated
            modified = true
            model[attr] = value 
            options.debug and console.log "update property #{attr}"

        # performs update propagation
        end = (err) ->
          eventEmitter.emit 'modelChanged', 'update', model, _.without _.keys(changes), 'id' if modified and !err?
          callback err

        # enrich specific models properties
        if modified and className is 'Player' and 'characters' of changes
          enrichCharacters model, end
        else if modified and className in ['Item', 'Event']
          async.parallel [
            (next) ->
              return next() unless 'map' of changes and className is 'Item'
              enrichMap model, next
            (next) ->
              return next() unless 'from' of changes and className is 'Event'
              enrichFrom model, next
            (next) ->
              enrichTypeProperties model, model, next
          ], end
        else 
          end null

    # Removes cached model when removed on server
    # May update players characters to reflect changes
    #
    # @param className [String] removed model class name
    # @param model [Object] raw removed model
    # @param  callback [Function] construction end callback, invoked with argument:
    # @option callback error [Error] an Error object, or null if no error occured
    onModelDeletion = (className, model, callback = ->) ->
      # manage field deletion first
      return eventEmitter.emit 'modelChanged', 'deletion', new Atlas.Field(model, callback) if className is 'Field'
      # other models deletion
      return callback null unless className of models
      removed = models[className][model.id]
      # quit if not cached
      return callback null unless removed?
      delete models[className][removed.id]
      options.debug and console.log "delete instance #{className} #{model.id}"
      
      # update player characters
      for id, player of models.Player when _.isArray player.characters
        length = player.characters.length
        # filter removed from value if needed
        player.characters = _.without player.characters, removed
        if length isnt player.characters.length
          options.debug and console.log "update player #{player.id} after removing a linked characters #{removed.id}"
          eventEmitter.emit 'modelChanged', 'update', player, ['characters']

      # update event and item if one of their linked is removed
      for model in _.values(models.Item).concat _.values models.Event
        properties = model.type.properties
        continue unless properties?
        changes = []
        # process each properties
        for prop, def of properties
          if def.type is 'object' and model[prop] is removed
            # set link to null
            model[prop] = null
            changes.push prop
          else if def.type is 'array' and _.isArray model[prop]
            length = model[prop].length
            # filter removed from value if needed
            model[prop] = _.without model[prop], removed
            changes.push prop if length isnt model[prop].length
        # indicate that model changed
        unless 0 is changes.length
          options.debug and console.log "update model #{model.id} after removing a linked object #{removed.id}"
          eventEmitter.emit 'modelChanged', 'update', model, changes

      # performs removal propagation
      eventEmitter.emit 'modelChanged', 'deletion', removed
      callback null 

    # Models locally represents object within Mythic-forge.
    # This class provide simple mechanisms to load a model from JSON representation
    class Model

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      # **Must be defined by subclasses**
      @_className: null

      # **private**
      # List of properties that must be defined in this instance.
      # **May be defined by subclasses**
      @_fixedAttributes: []

      # Model constructor: load the model from raw JSON
      #
      # @param raw [Object] raw attributes
      # @param callback [Function] loading end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the built model
      constructor: (raw, callback = ->) ->
        # affect id
        @id = raw?.id
        throw new Error "cannot create #{@constructor._className} without id" unless @id?
        @_load raw, => _.defer => callback null, @

      # **private**
      # Load the model values from raw JSON
      # Ensure the existence of fixed attributes
      # 
      # @param raw [Object] raw attributes
      # @param callback [Function] optionnal loading end callback. invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      _load: (raw, callback = ->) =>
        # copy raw attributes into current model, only keeping declared attributes
        for attr in @constructor._fixedAttributes
          unless attr is 'id'
            @[attr] = if attr of raw then raw[attr] else null
        callback null

    # Cached models are automatically wired to server once fetched. 
    # Any modification from server will be propagated: models are always up to date.
    # they are read-only: creation, modification and deletion are server privileges. 
    #
    # Models maintains a per-class local cache: once wired, they are stored for further use.
    class CachedModel extends Model

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      # **Must be defined by subclasses**
      @_className: null

      # **private**
      # List of properties that must be defined in this instance.
      # **May be defined by subclasses**
      @_fixedAttributes: []

      # **private**
      # Contains the server method used to fetch models. Set to null to disabled `fetch()`
      # **May be defined by subclasses**
      @_fetchMethod: null

      # **private**
      # List of properties that cannot be updated on this instance.
      # **Must be defined by subclasses**
      @_notUpdated: ['id']

      # Find models within the cache.
      # No server access done.
      #
      # @param conditions [Object] conditions the selected models must match  
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option models [Array<Model>] the matching models, may be empty if no model matched given conditions
      @find: (conditions, callback = ->) ->
        callback null, _.where models[@_className], conditions
      
      # Find a model within the cache.
      # No server access done.
      #
      # @param conditions [Object] conditions the selected models must match  
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the first matching models, may be null if no model matched given conditions
      @findOne: (conditions, callback = ->) ->
        callback null, _.findWhere models[@_className], conditions

      # Find a model with its id within the cache.
      # No server access done.
      #
      # @param id [String] the searched model id
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the corresponding model, or null if no model found with this id
      @findById: (id, callback = ->) ->
        @findOne {id:id}, callback

      # Find some models from there ids within the cache.
      # No server access done.
      #
      # @param ids [Array<String>] the searched model ids
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option models [Array<Model>] the matching models, may be empty if no model matched given ids
      @findCached: (ids, callback = ->) ->
        result = []
        for id, model of models[@_className] when id in ids
          result.push model
          # do not search already found ids
          ids.splice ids.indexOf(id), 1
          break if ids.lenght is 0

        callback null, result

      # Fetch some models from the server. For models that have linked properties, they are resolve at first level.
      # Local cache is updated with results.
      #
      # @param ids [Array<String>] the searched model ids
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option models [Array<Model>] the matching models, may be empty if no model matched given ids
      @fetch: (ids, callback = ->) ->
        throw new Error "fetch not suppored for #{@_className}" unless @_fetchMethod?
        rid = utils.rid()

        # load missing characters
        process = (reqId, err, results) =>
          return unless reqId is rid
          Atlas.gameNS.removeListener "#{@_fetchMethod}-resp", process
          return callback err if err?
          async.each results, (raw, next) =>
            model = @findById raw.id
            if model?
              # update cache with new value, as requested
              onModelUpdate @_className, raw, next
            else
              # add new model to local cache
              new Atlas[@_className] raw, next
          , (err) =>
            return callback err if err?
            @findCached _.pluck(results, 'id'), (err, results) =>
              callback err, results

        options.debug and console.log "fetch on server (#{@_fetchMethod}) instances: #{ids.join ','}"
        Atlas.gameNS.on "#{@_fetchMethod}-resp", process
        Atlas.gameNS.emit @_fetchMethod, rid, ids

      # Model constructor: load the model from raw JSON
      #
      # @param raw [Object] raw attributes
      # @param callback [Function] loading end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the built model
      constructor: (raw, callback = ->) ->
        super raw, (err) =>
          return callback err if err?
          # store inside models
          models[@constructor._className][@id] = @
          eventEmitter.emit 'modelChanged', 'creation', @
          callback null, @
    
    #-----------------------------------------------------------------------------
    # Model enrichment methods

    # Replace model's type by corresponding type model. 
    # If type is not cached yet, retrieve it on server and update model.
    #
    # @param model [Model] the enriched model
    # @param callback [Function] enrichment end callback, invoked with arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    enrichType = (model, callback = ->) ->
      return callback new Error "no type defined for #{model.constructor._className} #{model.id}" unless model.type?
      
      id = if 'object' is utils.type model.type then model.type.id else model.type
      TypeClass = Atlas["#{model.constructor._className}Type"]

      TypeClass.findById id, (err, type) ->
        return callback err if err?
        if type?
          # already cached
          model.type = type
          return callback null
        if 'object' is utils.type model.type
          # not cached, but all data here
          return model.type = new TypeClass model.type, callback
        # not cached, only id here: fetch from server
        TypeClass.fetch [id], (err, types) ->
          return callback err if err?
          return callback new Error "no type #{model.type} found for model #{model.constructor._className} #{model.id}" if types.length is 0
          model.type = types[0]
          callback null

    # Replace item's map by corresponding Map model. 
    # If Map is not cached yet, retrieve it on server and update item.
    #
    # @param item [Item] the enriched item
    # @param callback [Function] enrichment end callback, invoked with arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    enrichMap = (item, callback = ->) ->
      return callback null unless item.map?
      
      id = if 'object' is utils.type item.map then item.map.id else item.map
      Atlas.Map.findById id, (err, map) ->
        return callback err if err?
        if map?
          # already cached
          item.map = map
          return callback null
        # not cached: as we cannot fetch maps, just add available data (may only be an id)
        item.map = new Atlas.Map (if 'object' is utils.type item.map then item.map else id:item.map), callback

    # Replace players's characters by corresponding Item models. 
    # If Items are not cached yet, retrieve them on server and update player.
    #
    # @param player [Player] the enriched player
    # @param callback [Function] enrichment end callback, invoked with arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    enrichCharacters = (player, callback = ->) ->
      return callback unless _.isArray player.characters
      raws = player.characters.concat()
      toLoad = []
      player.characters = []

      # try to build model from raw version of characters
      async.each raws, (raw, next) ->
        id = if 'object' is utils.type raw then raw.id else raw
        Atlas.Item.findById id, (err, character) ->
          return next err if err?
          if character?
            # already cached
            player.characters.push character
            return next()
          if 'string' is utils.type raw
            # not cached, only id here
            toLoad.push id
            return next()
          # not cached, but all data here
          player.characters.push new Atlas.Item raw, next
      , (err) ->
        return callback err if err?
        return callback null if toLoad.length is 0

        # fetch missing characters from server
        Atlas.Item.fetch toLoad, (err, characters) ->
          return callback err if err?
          player.characters.push character for character in characters
          callback null

    # Replace event's from by corresponding Item model. 
    # If Item is not cached yet, retrieve it on server and update item.
    #
    # @param event [Event] the enriched event
    # @param callback [Function] enrichment end callback, invoked with arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    enrichFrom = (model, callback = ->) ->
      return callback unless model.from?

      # try to build model from raw version of item
      id = if 'object' is utils.type model.from then model.from.id else model.from
      Atlas.Item.findById id, (err, from) ->
        return callback err if err?
        if from?
          # already cached
          model.from = from
          return callback null
        if 'object' is utils.type model.from
          # not cached, but all data here
          return model.from = new Atlas.Item model.from, callback
        # not cached, only id here: fetch it from server
        Atlas.Item.fetch [id], (err, froms) ->
          return callback err if err?
          model.from = if froms?[0]? then froms[0] else null
          callback null

    # Add properties declared within a given type to the specified model.
    # Values are taken from the raw JSON object or from the type defaults if missing
    #
    # @param model [Model] the enriched model
    # @param raw [Object] its raw JSON attributes
    # @param callback [Function] enrichment end callback, invoked with arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    enrichTypeProperties = (model, raw, callback = ->) ->
      return callback new Error "no type found for model #{model.constructor._className} #{model.id}" unless model.type?.properties?
      delete model.__dirty__
      async.each _.pairs(model.type.properties), ([attr, spec], next) ->
        model[attr] = (
          if attr of raw
            raw[attr]
          else
            switch spec.type
              when 'object' then null 
              when 'array' then []
              else spec.def
        )
        # enhance raw linked objects with their corresponding models if possible
        return next() unless spec.type in ['object', 'array']
        processed = model[attr]
        processed = [processed] if 'object' is spec.type
        modified = false
        async.map processed, (val, nextVal) ->
          isString = 'string' is utils.type val
          return nextVal val unless isString or val?._className?
          modified = true
          if isString
            # look into items, and then into events
            Atlas.Item.findById val, (err, linked) ->
              # returns found item, or search for events
              return nextVal err, linked if err? or linked?
              Atlas.Event.findById val, (err, linked) ->
                # returns found event
                return nextVal err, linked if err? or linked?
                # linked not found: indicates it.
                model.__dirty__ = true
                nextVal err, val
          else
            # construct a model around linked object, if possible
            Atlas[val._className].findById val.id, (err, linked) ->
              return nextVal err if err?
              # reuse existing model
              return nextVal null, linked if linked?
              # we have data: add it
              nextVal err, new Atlas[val._className] val
        , (err, processed) ->
          return callback err if err?
          if modified
            model[attr] = if 'object' is spec.type then processed[0] else processed
          next()

      , callback

    #-----------------------------------------------------------------------------
    # Map models

    # A map contains Fields, and may host several Items
    # Provide a special method `consult()` to get load map content
    class Atlas.Map extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'Map'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['kind']

      # **private**
      # request identifier to avoid multiple concurrent server call.
      _rid: null

      # **private**
      # callback used to notify consult caller from results
      _consultCallback: null

      # Map constructor: load the model from raw JSON, and wire to server consult responses
      #
      # @param raw [Object] raw attributes
      # @param callback [Function] loading end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      constructor: (raw, callback) ->
        eventEmitter.on 'connected', doConnect = =>
          Atlas.gameNS.on 'consultMap-resp', @_onConsult
        doConnect() if connected
        @_rid = null
        super raw, callback

      # Allows to retrieve items and fields on this map by coordinates, in a given rectangle.
      # Fields and items are retrived, triggering `modelChanged` event when enrich into their corresponding models.
      # Those models are returned to caller through the callback parameters.
      # Only one consultation at time is allowed.
      #
      # @param low [Object] lower-left coordinates of the rectangle
      # @option args low x [Number] abscissa lower bound (included)
      # @option args low y [Number] ordinate lower bound (included)
      # @param up [Object] upper-right coordinates of the rectangle
      # @option args up x [Number] abscissa upper bound (included)
      # @option args up y [Number] ordinate upper bound (included)  
      # @param callback [Function] consultation end callback, invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      # @option callback fields [Array<Field>] array of retrieved fields (may be empty)
      # @option callback items [Array<Item>] array of retrieved items (may be empty)
      consult: (low, up, callback = ->) =>
        return callback new Error "consult() already in progress" if @_rid?
        @_rid = utils.rid()
        @_consultCallback = callback
        options.debug and console.log "Consult map #{@id} between #{low.x}:#{low.y} and #{up.x}:#{up.y}"
        # emit the message on the socket.
        Atlas.gameNS.emit 'consultMap', @_rid, @id, low.x, low.y, up.x, up.y

      # **private**
      # Return callback of consultMap server operation.
      #
      # @param reqId [String] client request id
      # @param err [String] error string. null if no error occured
      # @param items [Array<Item>] array (may be empty) of concerned items.
      # @param fields [Array<Field>] array (may be empty) of concerned fields.
      _onConsult: (reqId, err, items, fields) =>
        return unless @_rid is reqId
        @_rid = null
        if err?
          options.debug and console.error "Fail to retrieve map content: #{err}" 
          return @_consultCallback new Error err
        options.debug and console.log "#{items.length} item(s) and {fields.length} field(s) received for map #{@id}"
        # enrich returned models: items will be cached, not fields, but all will trigger events
        async.map items, (raw, next) ->
          Atlas.Item.findById raw.id, (err, item) -> 
            return next err if err?
            return next null, item if item?
            new Atlas.Item raw, next
        , (err, items) =>
          @_consultCallback err, (new Atlas.Field raw for raw in fields), items

    #-----------------------------------------------------------------------------
    # Field and FieldType models

    # An FieldType defines field's images
    class Atlas.FieldType extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'FieldType'

      # **private**
      # Contains the server method used to fetch models.
      @_fetchMethod: 'getTypes'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['descImage', 'images']

    # Field modelize field tiles on map (one field par tile).
    # Field are the only models that are not cached on client side, to avoid memory waste
    class Atlas.Field extends Model

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'Field'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['mapId', 'typeId', 'num', 'x', 'y']

    #-----------------------------------------------------------------------------
    # Item and ItemType models

    # An ItemType defines dynamic properties of a given Item
    class Atlas.ItemType extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'ItemType'

      # **private**
      # Contains the server method used to fetch models.
      @_fetchMethod: 'getTypes'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['descImage', 'images', 'properties', 'quantifiable']

    # Item modelize any objects and actor that can be found on a map, and may be controlled by players
    # An item always have a type, which is systematically populated from cache or server during initialization.
    # Links to other items and event are resolved locally from cache. 
    # If some of them are not resolved, a `__dirty__` attrribute is added, and you can resolve them by fetchinf the item.
    class Atlas.Item extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'Item'

      # **private**
      # Contains the server method used to fetch models.
      @_fetchMethod: 'getItems'

      # **private**
      # List of properties that cannot be updated on this instance.
      @_notUpdated: ['id', 'type']

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['map', 'x', 'y', 'imageNum', 'state', 'transition', 'quantity', 'type']

      # **private**
      # Load the model values from raw JSON
      # Ensure the existence of fixed attributes
      # 
      # @param raw [Object] raw attributes
      # @param callback [Function] optionnal loading end callback. invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      _load: (raw, callback = ->) =>
        # do not invoke callback now
        super raw, (err) =>
          return callback err if err?
          # first, enrich type
          enrichType @, (err) =>
            return callback err if err?
            # then add type properties
            enrichTypeProperties @, raw, (err) =>
              return callback err if err?
              # then enrich map
              enrichMap @, callback

    #-----------------------------------------------------------------------------
    # Event and EventType models

    # An EventType defines dynamic properties of a given Event
    class Atlas.EventType extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'EventType'

      # **private**
      # Contains the server method used to fetch models.
      @_fetchMethod: 'getTypes'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['descImage', 'properties', 'template']

    # Event modelize anything that can be issued by an Item, and that is not on map
    # An event always have a type and a from item, which are systematically populated from cache or server during initialization.
    # Links to other items and event are resolved locally from cache. 
    # If some of them are not resolved, a `__dirty__` attrribute is added, and you can resolve them by fetchinf the event.
    class Atlas.Event extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'Event'

      # **private**
      # Contains the server method used to fetch models.
      @_fetchMethod: 'getEvents'

      # **private**
      # List of properties that cannot be updated on this instance.
      @_notUpdated: ['id', 'type']

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['created', 'updated', 'from', 'type']

      # **private**
      # Load the model values from raw JSON
      # Ensure the existence of fixed attributes
      # 
      # @param raw [Object] raw attributes
      # @param callback [Function] optionnal loading end callback. invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      _load: (raw, callback = ->) =>
        # do not invoke callback now
        super raw, (err) =>
          return callback err if err?
          # first, enrich type
          enrichType @, (err) =>
            return callback err if err?
            # then add type properties
            enrichTypeProperties @, raw, (err) =>
              return callback err if err?
              # then enrich from
              enrichFrom @, callback

    #-----------------------------------------------------------------------------
    # Player model

    # Player modelize the human (or bot) player acccount, with it email, infos, preferences and avatars (characters)
    # Player's characters are systematically populated from cache or server during initialization.
    class Atlas.Player extends CachedModel

      # **private**
      # Class name of the managed model, for wiring to server and debugging purposes
      @_className: 'Player'

      # **private**
      # List of properties that must be defined in this instance.
      @_fixedAttributes: ['email', 'provider', 'password', 'lastConnection', 'firstName', 'lastName', 'isAdmin', 'characters', 'prefs']

      # **private**
      # Load the model values from raw JSON
      # Ensure the existence of fixed attributes
      # 
      # @param raw [Object] raw attributes
      # @param callback [Function] optionnal loading end callback. invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      _load: (raw, callback = ->) =>
        # do not invoke callback now
        super raw, (err) =>
          return callback err if err?
          # constructs Items for the corresponding characters
          enrichCharacters @, callback

    #-----------------------------------------------------------------------------
    # Rule Service

    # The rule service is responsible for resolving and executing rules.
    # It send relevant instruction to server to performs those tasks.
    class RuleService

      # **private**
      # Object that store resolution original parameters. Also avoid multiple concurrent server call.
      _resolveArgs: null

      # **private**
      # Object that store execution original parameters. Also avoid multiple concurrent server call.
      _executeArgs: null
      
      # Constructor: import rules
      constructor: ->
        eventEmitter.on 'connected', connectedCb = =>
          # bind operation responses
          Atlas.gameNS.on 'resolveRules-resp', @_onResolveRules
          Atlas.gameNS.on 'executeRule-resp', @_onExecuteRule
        connectedCb() if connected

      # Triggers rules resolution for a given actor, **on server side**.
      # 
      # @overload resolve(player, callback)
      #   Resolves applicable rules for a spacific player
      #   @param player [Player|String] the player or its id
      #
      # @overload resolve(actor, x, y, callback)
      #   Resolves applicable rules at a specified coordinate
      #   @param actor [Item|String] the actor item or its id
      #   @param x [Number] the targeted x coordinate
      #   @param y [Number] the targeted y coordinate
      #
      # @overload resolve(actor, target, callback)
      #   Resolves applicable rules at for a specific target
      #   @param actor [Item|String] the actor item or its id
      #   @param target [Item|String] the targeted item or its id
      #
      # @param callback [Function] resolution end callback, invoked with arguments
      # @option callback err [Error] an Error object, or null if no error occured
      # @option callback results [Object] applicable rules in an associative array, where rule id is key, 
      # and value an array of applicable targets :
      # - params [Array] awaited parameters (may be empty)
      # - category [String] rule category
      # - target [Model] applicable target (enriched model)
      resolve: (args..., callback = ->) =>
        # do not allow multiple resolution
        return callback new Error "resolution already in progress" if @_resolveArgs?
        @_resolveArgs =
          rid: utils.rid()
          callback: callback
        actorId = if 'object' is utils.type args[0] then args[0].id else args[0]
            
        if args.length is 1
          # resolve for player
          options.debug and console.log "resolve rules for player #{actorId}"
          Atlas.gameNS.emit 'resolveRules', @_resolveArgs.rid, actorId
        else if args.length is 2
          # resolve for actor over a target
          targetId = if 'object' is utils.type args[1] then args[1].id else args[1]
          options.debug and console.log "resolve rules for #{actorId} and target #{targetId}"
          Atlas.gameNS.emit 'resolveRules', @_resolveArgs.rid, actorId, targetId
        else if args.length is 3
          # resolve for actor over a tile
          x = args[1]
          y = args[2]
          options.debug and console.log "resolve rules for #{actorId} at #{x}:#{y}"
          Atlas.gameNS.emit 'resolveRules', @_resolveArgs.rid, actorId, x, y
        else 
          return callback new Error "Can't resolve rules with arguments #{arguments}"

      # Triggers a specific rule execution for a given actor on a target
      #
      # @param ruleName [String] the rule name
      # @overload execute(ruleName, player, params)
      #   Executes rule for a player
      #   @param player [String] the concerned player Id
      #
      # @overload execute(ruleName, actor, target, params)
      #   Executes rule for an actor and a target
      #   @param actor [ObjectId] the concerned actor Id
      #   @param target  [ObjectId] the targeted item's id
      #
      # @param params [Object] the rule parameters
      # @param callback [Function] resolution end callback, invoked with arguments
      # @option callback err [Error] an Error object, or null if no error occured
      # @option callback result [Object] arbitrary rule results.
      execute: (ruleName, args..., params, callback = ->) =>
        # do not allow multiple resolution
        return callback new Error "execution already in progress" if @_executeArgs?
        @_executeArgs =
          rid: utils.rid()
          callback: callback
        actorId = if 'object' is utils.type args[0] then args[0].id else args[0]

        if args.length is 1
          # execute over a player
          options.debug and console.log "execute rule #{ruleName} for player #{actorId}"
          Atlas.gameNS.emit 'executeRule', @_executeArgs.rid, ruleName, actorId, params
        else if args.length is 2
          # execute for actor over a target
          targetId = if 'object' is utils.type args[1] then args[1].id else args[1]
          options.debug and console.log "execute rule #{ruleName} for #{actor} and target #{target}"
          Atlas.gameNS.emit 'executeRule', @_executeArgs.rid, ruleName, actorId, targetId, params
        else 
          return callback new Error "Can't execute rules with arguments #{arguments}"

      # **private**
      # Rules resolution handler: enrich results with models and invoke original callback.
      #
      # @param reqId [String] the request unic identifier
      # @param err [String] an error string, or null if no error occured
      # @param results [Object] applicable rules, where rule id is key, 
      # and value an array of object targets with params array (may be empty), category and applicable target
      _onResolveRules: (reqId, err, results) =>
        return unless reqId is @_resolveArgs?.rid
        callback = @_resolveArgs.callback
        # reset to allow further calls.
        @_resolveArgs = null

        if err?
          options.debug and console.error "Fail to resolve rules: #{err}" 
          return callback new Error "Fail to resolve rules: #{err}" 

        # enrich targets with models
        async.each _.keys(results), (ruleId, next) ->
          async.each results[ruleId], (appliance, next) ->
            # players, items and events will have _className, fields not
            target = appliance.target
            if target._className?
              ModelClass = Atlas[target._className]
              # get the existing model from the collection
              ModelClass.findById target.id, (err, model) =>
                return next err if err?
                if model?
                  appliance.target = model
                  return next null
                # not existing ? adds it
                appliance.target = new ModelClass target, next
            else
              appliance.target = new Atlas.Field target, next
          , next
        , (err) ->
          results = undefined if err?
          callback err, results

      # **private**
      # Rules execution handler: invoke original callback with rule results.
      #
      # @param reqId [String] the request unic identifier
      # @param err [String] an error string, or null if no error occured
      # @param result [Object] the rule final result. Depends on the rule.
      _onExecuteRule: (reqId, err, result) =>
        return unless reqId is @_executeArgs?.rid
        callback = @_executeArgs.callback
        # reset to allow further calls.
        @_executeArgs = null

        return callback null, result unless err?
        options.debug and console.error "Fail to execute rule: #{err}" 
        return callback new Error "Fail to execute rule: #{err}" 

    # Only provide a singleton of RuleService
    Atlas.ruleService = new RuleService()

    # return created namespace
    Atlas

)(@)