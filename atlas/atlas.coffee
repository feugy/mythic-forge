( ->

  # Atlas library has some dependencies:
  # 
  # - async@0.2.7
  # - jquery@2.0.0
  # - socket.io@1.0.0-pre
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
  # - preCreate [Function] extension point invoked when a creation is received from server, before processing data. Invoked with parameters :
  # @param className [String] created model class name
  # @param created [Object] raw created model
  # @param  callback [Function] end callback to resume update process. Invoke with null and created, or with truthy value as first argument to cancel update
  # - preUpdate [Function] extension point invoked when an update is received from server, before processing data. Invoked with parameters :
  # @param className [String] updated model class name
  # @param changes [Object] raw new values (always contains id)
  # @param  callback [Function] end callback to resume update process. Invoke with null and changes, or with truthy value as first argument to cancel update
  # - preDelete [Function] extension point invoked when a deletion is received from server, before processing data. Invoked with parameters :
  # @param className [String] deleted model class name
  # @param deleted [Object] raw deleted model
  # @param  callback [Function] end callback to resume update process. Invoke with null and deleted, or with truthy value as first argument to cancel update
  @factory = (eventEmitter, options = {}) ->
      
    # internal state
    isLoggingOut = false
    connected = false
    connecting = false
    player = null
      
    # Atlas global namespace
    Atlas = 
      # socket.io high level object
      socket: null

      # socket.io namespace for incoming updates
      updateNS: null
      
      # socket.io namespace for sending messages to server
      gameNS: null
      
      # refer current options
      options: options
      
      # keep event emitter
      eventEmitter: eventEmitter
       
    # read-only player, populated by `connect()`
    Object.defineProperty Atlas, 'player', 
      get: -> player
      enumerable: true
            
    # read-only connection flag, populated by `connect()`
    Object.defineProperty Atlas, 'connected', 
      get: -> connected
      enumerable: true
      
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
        "req#{('0' for i in [0..5-id.length]).join ''}#{id}"
      
    #-----------------------------------------------------------------------------
    # Connection to server
      
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
        query:"token=#{token}", 
        transports: ['websocket', 'polling', 'flashsocket']

      Atlas.socket.on 'close', => console.log "connect_failed", arguments

      Atlas.socket.on 'error', (err) =>
        if connecting or connected
          connected = false
          connecting = false
          callback new Error err

      Atlas.socket.on 'disconnect', (reason) =>
        connecting = false
        connected = false
        return if isLoggingOut
        options.debug and console.log "disconnected for #{reason}"
        callback new Error 'disconnected'
      
      Atlas.socket.io.on 'reconnect_attempt', ->
        # don't forget to set connecting flag again for error handling
        connecting = true

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
              Atlas.socket.io.opts.query = "token=#{raw.token}"
              end()
          (end) ->
            # wired both namespaces
            async.forEach [
              {attr:'gameNS', ns:'game'}
              {attr:'updateNS', ns:'updates'}
            ], (spec, next) ->
              Atlas[spec.attr] = Atlas.socket.io.socket "/#{spec.ns}"
              Atlas[spec.attr].once 'connect', next
              Atlas[spec.attr].once 'connect_error', next
            , end
        ], (err) ->
          connecting = false
          connected = !err?
          return callback err if err?
          # enrich player before keeping him in cache
          player = new Atlas.Player raw, (err) ->
            eventEmitter.emit 'connected', player
            callback err, player
        
    # Disconnect current player from server 
    # 
    # @param callback [Function] invoked when player is properly disconnected.
    Atlas.disconnect = (callback) =>
      return callback() unless connected
      isLoggingOut = true
      player = null
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
      
    # For each sent request, corresponding name, arguments and callback
    # request id is used as key
    requests = {}

    # bounds to server updates
    eventEmitter.on 'connected', ->
      factory = (hook, process) ->
        (className, model) ->
          # immediately process message...
          return process className, model unless _.isFunction Atlas.options?[hook]
          # ...or use hook that may cancel processing
          Atlas.options[hook] className, model, (err, model) ->
            process className, model unless err
      Atlas.updateNS.on 'creation', factory 'preCreate', Atlas.modelCreation
      Atlas.updateNS.on 'update', factory 'preUpdate', Atlas.modelUpdate
      Atlas.updateNS.on 'deletion',  factory 'preDelete', Atlas.modelDeletion

    # Add the created model into relevant cache
    #
    # @param className [String] created model class name
    # @param model [Object] raw created model
    # @param  callback [Function] construction end callback, invoked with argument:
    # @option callback error [Error] an Error object, or null if no error occured
    Atlas.modelCreation = (className, model, callback = ->) ->
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
    # @param  callback [Function] construction end callback, invoked with two arguments:
    # @option callback error [Error] an Error object, or null if no error occured
    # @option callback model [Model] the updated cached model
    Atlas.modelUpdate = (className, changes, callback = ->) ->
      return callback null unless className of models
      # first, get the cached model and quit if not found
      Atlas[className].findById changes?.id, (err, model) ->
        return callback err if err?
        unless model?
          # update on an unexisting model: fetch it if possible
          if Atlas[className]._fetchMethod?
            return Atlas[className].fetch [changes.id], (err, models) -> callback err, models?[0]
          else
            return callback null 
        options.debug and console.log "process update for model #{model.id} (#{className})", changes
        # then, update the local cache
        modifiedFields = []
        for attr, value of changes
          unless attr in Atlas[className]._notUpdated
            # ignore change if value is identical or if field ignored
            modifiedFields.push attr
            model[attr] = value 
            options.debug and console.log "update property #{attr}"

        # performs update propagation
        end = (err) ->
          options.debug and console.log "end of update for model #{model.id} (#{className})", modifiedFields, err
          if modifiedFields.length isnt 0 and !err?
            eventEmitter.emit 'modelChanged', 'update', model, modifiedFields 
          callback err, model

        # enrich specific models properties
        if modifiedFields.length isnt 0 and className is 'Player' and 'characters' of changes
          enrichCharacters model, end
        else if modifiedFields.length isnt 0 and className in ['Item', 'Event']
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
    Atlas.modelDeletion = (className, model, callback = ->) ->
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
        @_load raw, (err) => _.defer => callback err, @

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
        _.defer => callback null, _.where models[@_className], conditions
      
      # Find a model within the cache.
      # No server access done.
      #
      # @param conditions [Object] conditions the selected models must match  
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the first matching models, may be null if no model matched given conditions
      @findOne: (conditions, callback = ->) ->
        _.defer => callback null, _.findWhere models[@_className], conditions

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
        copy = ids.concat []
        result = []
        for id, model of models[@_className] when id in copy
          # do not search already found ids
          copy.splice copy.indexOf(id), 1
          # keep order
          result[ids.indexOf id] = model
          break if copy.lenght is 0

        _.defer => callback null, result

      # Fetch some models from the server. For models that have linked properties, they are resolve at first level.
      # Local cache is updated with results.
      #
      # @param ids [Array<String|Model>] the searched model or their ids
      # @param callback [Function] end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option models [Array<Model>] the matching models, may be empty if no model matched given ids
      @fetch: (ids, callback = ->) ->
        throw new Error "fetch not suppored for #{@_className}" unless @_fetchMethod?
        rid = utils.rid()
        # only keep ids
        ids = _.map ids, (obj) -> if _.isObject(obj) and 'id' of obj then obj.id else obj

        # load missing characters
        options.debug and console.log "fetch on server (#{@_fetchMethod}) instances: #{ids.join ','}"
        Atlas.gameNS.on "#{@_fetchMethod}-resp", process = (reqId, err, results) =>
          return unless reqId is rid
          Atlas.gameNS.removeListener "#{@_fetchMethod}-resp", process
          return callback err if err?
          async.map results, (raw, next) =>
            @findById raw.id, (err, model) =>
              return next err if err?
              if model?
                # update cache with new value, as requested
                Atlas.modelUpdate @_className, raw, next
              else
                # add new model to local cache
                new Atlas[@_className] raw, next
          , callback
        Atlas.gameNS.emit @_fetchMethod, rid, ids

      # Model constructor: load the model from raw JSON
      #
      # @param raw [Object] raw attributes
      # @param callback [Function] loading end callback, invoked with arguments:
      # @option err [Error] an Error object or null if no error occured
      # @option model [Model] the built model
      constructor: (raw, callback = ->) ->
        super raw, (err) =>
          if err?
            delete models[@constructor._className][@id]
            return callback err 
          eventEmitter.emit 'modelChanged', 'creation', @
          callback null, @
        # store inside models immediately
        models[@constructor._className][@id] = @
    
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
      return callback null unless _.isArray player.characters
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
      return callback null unless model.from?
      
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
      return callback new Error "no type found for model #{model.constructor._className} #{model.id}" unless model.type?
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
          return nextVal null, val unless isString or val?._className?
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
                options.debug and console.log "linked #{val} in #{attr} not found, model #{model.id} is dirty"
                model.__dirty__ = true
                nextVal err, val
          else
            # construct a model around linked object, if possible
            Atlas[val._className].findById val.id, (err, linked) ->
              return nextVal err if err?
              # reuse existing model
              return nextVal null, linked if linked?
              # we have data: add it
              new Atlas[val._className] val, nextVal
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
      @_fixedAttributes: ['kind', 'tileDim']

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
        options.debug and console.log "#{items.length} item(s) and #{fields.length} field(s) received for map #{@id}"
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
    
    # manages transition changes on Item's updates
    eventEmitter.on 'modelChanged', (event, operation, model, changes) ->
      return unless operation is 'update' and model.constructor._className is 'Item' and 'transition' in changes 
      model._transition = model.transition

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
      # Provide the transition used to animate items.
      # Do not use directly used `model.getTransition` because it's not reset when not appliable.
      _transition: null
      
      # **private**
      # Load the model values from raw JSON
      # Ensure the existence of fixed attributes
      # 
      # @param raw [Object] raw attributes
      # @param callback [Function] optionnal loading end callback. invoked with arguments:
      # @option callback error [Error] an Error object, or null if no error occured
      _load: (raw, callback = ->) =>
        @_transition = null
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
      
      # Returns the Item's transition. Designed to be used only one time.
      # When restrieved, the transition is reset until its next change.
      #
      # @return the current transition, or null if no transition available.
      getTransition: =>
        transition = @_transition 
        @_transition = null
        transition

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
    # If some of them are not resolved, a `__dirty__` attrribute is added, and you can resolve them by fetching the event.
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
      @_fixedAttributes: ['email', 'provider', 'password', 'lastConnection', 'firstName', 'lastName', 'isAdmin', 'characters', 'prefs', 'token']

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
      # @param restriction [Array<String>|String] restrict resolution to a given categories or ruleId. 
      # If an array, only rule that match one of the specified category is resolved.
      # If a single string, only rule that has this id is resolved.
      # Otherwise all rules are resolved.
      # @param callback [Function] resolution end callback, invoked with arguments
      # @option callback err [Error] an Error object, or null if no error occured
      # @option callback results [Object] applicable rules in an associative array, where rule id is key, 
      # and value an array of applicable targets :
      # - params [Array] awaited parameters (may be empty)
      # - category [String] rule category
      # - target [Model] applicable target (enriched model)
      resolve: (args..., restriction, callback = ->) =>
        rid = utils.rid()
        requests[rid] = 
          restriction: restriction
          callback: callback
        params = requests[rid]
        params.actorId = if 'object' is utils.type args[0] then args[0].id else args[0]
            
        if args.length is 1
          # resolve for player
          options.debug and console.log "resolve rules for player #{params.actorId}"
          Atlas.gameNS.emit 'resolveRules', rid, params.actorId, params.restriction
        else if args.length is 2
          # resolve for actor over a target
          params.targetId = if 'object' is utils.type args[1] then args[1].id else args[1]
          options.debug and console.log "resolve rules for #{params.actorId} and target #{params.targetId}"
          Atlas.gameNS.emit 'resolveRules', rid, params.actorId, params.targetId, params.restriction
        else if args.length is 3
          # resolve for actor over a tile
          params.x = args[1]
          params.y = args[2]
          options.debug and console.log "resolve rules for #{params.actorId} at #{params.x}:#{params.y}"
          Atlas.gameNS.emit 'resolveRules', rid, params.actorId, params.x, params.y, params.restriction
        else 
          return _.defer -> callback new Error "Can't resolve rules with arguments #{JSON.stringify arguments, null, 2}"

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
        rid = utils.rid()
        requests[rid] = 
          name: ruleName
          params: params
          callback: callback
        params = requests[rid]
        params.actorId = if 'object' is utils.type args[0] then args[0].id else args[0]
        
        if args.length is 1
          # execute over a player
          options.debug and console.log "execute rule #{params.name} for player #{params.actorId}"
          Atlas.gameNS.emit 'executeRule', rid, params.name, params.actorId, params.params
        else if args.length is 2
          # execute for actor over a target
          params.targetId = if 'object' is utils.type args[1] then args[1].id else args[1]
          options.debug and console.log "execute rule #{params.name} for #{params.actorId} and target #{params.targetId}"
          Atlas.gameNS.emit 'executeRule', rid, params.name, params.actorId, params.targetId, params.params
        else 
          return _.defer -> callback new Error "Can't execute rules with arguments #{JSON.stringify arguments, null, 2}"
        
      # Indicates that service is busy
      # @return true if a resolution or execution is already in progress
      isBusy: => 
        return true for key of requests 
        return false
      
      # **private**
      # Rules resolution handler: enrich results with models and invoke original callback.
      #
      # @param reqId [String] the request unic identifier
      # @param err [String] an error string, or null if no error occured
      # @param results [Object] applicable rules, where rule id is key, 
      # and value an array of object targets with params array (may be empty), category and applicable target
      _onResolveRules: (reqId, err, results) =>
        return unless reqId of requests
        callback = requests[reqId].callback
        # reset to allow further calls.
        delete requests[reqId]
        
        if err?
          options.debug and console.error "Fail to resolve rules: #{err}" 
          return callback new Error "Fail to resolve rules: #{err}" 

        # enrich targets with models
        async.each _.keys(results), (ruleId, next) ->
          async.each results[ruleId], (appliance, next) ->
            # players, items and events will have _className, fields not
            target = appliance.target
            if target._className?
              options.debug and console.log "#{ruleId} apply on #{target._className} #{target.id}"
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
              options.debug and console.log "#{ruleId} apply on field #{target.x} #{target.y}"
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
        return unless reqId of requests
        callback = requests[reqId].callback
        # reset to allow further calls.
        delete requests[reqId]
        
        return callback null, result unless err?
        options.debug and console.error "Fail to execute rule: #{err}" 
        return callback new Error "Fail to execute rule: #{err}" 

    # Only provide a singleton of RuleService
    Atlas.ruleService = new RuleService()
    # make some alias
    Atlas.executeRule = Atlas.ruleService.execute
    Atlas.resolveRules = Atlas.ruleService.resolve

    #-----------------------------------------------------------------------------
    # Image Service

    # The rule service is responsible for retreiveing and storring images in a cache.
    # When requesting multiple time the same image, it stacks requester callback and invoke
    # them when the image is ready. 
    # It immediately returns the existing image when cached. 
    class ImageService

      # **private**        
      # Temporary storage of caller callback  for pending images
      _pendingStacks: {}

      # **private**
      # Image local cache, that store Image objects
      _cache: {}
      
      # **private**
      # Image data local cache, that store Image objects. 
      # Retention to 3 seconds only because it cost a lot of memory
      _dataCache: {}
      
      # **private**
      # Timestamps added to image request to server, avoiding cache
      _timestamps: {}
      
      # Load an image. Once it's available, the callback is invoked
      # If this image has already been loaded (url used as key), the event is imediately emitted.
      #
      # @param image [String] the image **ABSOLUTE** url
      # @param callback [Function] retrieval end callback, invoked with arguments
      # @option callback err [Error] an Error object, or null if no error occured
      # @option callback key [String] key used to retrieved image data (image url)
      # @option callback data [Object] the image data
      load: (image, callback) =>
        isLoading = false
        return isLoading unless image?
        # Use cache if available, with a timeout to simulate asynchronous behaviour
        if image of @_cache
          _.defer =>
            callback null, image, @_cache[image]
        else if image of @_pendingStacks
          # add a new listener for this image.
          @_pendingStacks[image].push callback
        else
          @_pendingStacks[image] = [callback]
          # creates an image facility
          imgData = new Image()
          # bind loading handlers
          $(imgData).load @_onImageLoaded
          $(imgData).error @_onImageFailed
          @_timestamps[image] = new Date().getTime()
          # adds a timestamped value to avoid browser cache
          imgData.src = "#{image}?#{@_timestamps[image]}"

      # Returns the image content from the cache, or null if the image was not requested yet
      # 
      # @param key [String] image key requested
      # @return the loaded DOM image node, or null if no image corresponding to key
      getImage: (key) =>
        return null unless key of @_cache
        @_cache[key]
        
      # Gets the base 64 image data from an image
      #
      # @param key [String] image key requested
      # @return the base 64 corresponding image data
      getImageString: (key) ->
        return null unless key of @_cache
        # reuse data cache if possible
        return @_dataCache[key] if key of @_dataCache
        canvas = $("<canvas></canvas>")[0]
        canvas.width = @_cache[key].width
        canvas.height = @_cache[key].height
        # Copy the image contents to the canvas
        ctx = canvas.getContext '2d'
        ctx.drawImage @_cache[key], 0, 0
        data = canvas.toDataURL 'image/png'
        # store in data cache for 3 seconds
        @_dataCache[key] = data
        _.delay =>
          delete @_dataCache[key]
        , 3000
        data
      
      # **private**
      # Handler invoked when an image finisedh to load. Emit the `imageLoaded` event. 
      #
      # @param event [Event] image loading success event
      _onImageLoaded: (event) =>
        # get only the image without host, port and base path
        key = null
        src = event.target.src.replace /\?\d*$/, ''
        for image of @_pendingStacks when new RegExp("#{image}$").test src 
          key = image 
          break
        return unless key?
        # remove pending stack
        stack = @_pendingStacks[key]
        delete @_pendingStacks[key]
        options.debug and console.log "store in cache image #{key}"
        # strore image data and invoke callbacks
        @_cache[key] = event.target
        callback null, key, @_cache[key] for callback in stack
    
      # **private**
      # Handler invoked when an image failed loading. Also emit the `imageLoaded` event.
      # @param event [Event] image loading fail event
      _onImageFailed: (event) =>
        # get only the image without host, port and base path
        key = null
        src = event.target.src.replace /\?\d*$/, ''
        for image of @_pendingStacks when new RegExp("#{image}$").test src
          key = image 
          break
        return unless key?
        # remove pending stack
        stack = @_pendingStacks[key]
        delete @_pendingStacks[key]
        options.debug and console.log "image #{src} loading failed"
        # invoke callbacks
        callback new Error("#{key} image not found"), key for callback in stack

    # Only provide a singleton of ImageService
    Atlas.imageService = new ImageService()

    # return created namespace
    Atlas

)(@)