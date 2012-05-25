define ['lib/backbone', 'connector'], (Backbone, connector) ->


  # item local cache. Items are stored by ids.
  cache = {}

  class Item extends Backbone.Model

    # **private**
    # static flag to avoid multiple concurrent server call.
    @_fetchRunning: false

    # Gets items of a given map between coordinates
    #
    # @param lowX [Number] abscissa lower bound (included)
    # @param lowY [Number] ordinate lower bound (included)
    # @param upX [Number] abscissa upper bound (included)
    # @param upY [Number] ordinate upper bound (included)  
    @fetchByCoord: (lowX, lowY, upX, upY) =>
      return if @_fetchRunning
      @_fetchRunning = true
      console.log "Consult map items between #{lowX}:#{lowY} and #{upX}:#{upY}"
      # emit the message on the socket.
      connector.gameSocket.emit 'consultMap', lowX, lowY, upX, upY

    # **private**
    # Return callback of consultMap server operation.
    #
    # @param err [String] error string. null if no error occured
    # @param rawItems [Array<Item>] array (may be empty) of concerned items.
    @_onConsultMap: (err, rawItems) =>
      return console.err "Fail to retrieve map content: #{err}" if err?
      console.log "#{rawItems.length} map item(s) received"
      # instanciate models from the rawItems
      items = []
      for rawItem in rawItems
        item = new Item rawItem
        cache[item.get('_id')] = item
        items.push item
      # propagate results.
      connector.dispatcher.trigger 'onFetchByCoord', items
      @_fetchRunning = false

    # Item constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 
      @idAttribute = '_id'

  # connect server response callbacks
  connector.gameSocket.on 'consultMap-resp', Item._onConsultMap

  return Item