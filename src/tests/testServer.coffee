server = require '../main/web/server'
socketClient = require 'socket.io-client'
Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
request = require 'request'

port = 9090
rootUrl = "http://localhost:#{port}"

module.exports = 

  setUp: (end) ->
    # given a clean ItemTypes and Items collections
    ItemType.collection.drop -> Item.collection.drop -> 
      # given a working server
      server.listen port, 'localhost', ->
        console.log "test server started on port #{port}"
        end()

  'given a started server': 

    'should the server be responding': (test) ->
      request "#{rootUrl}/konami", (err, res, body) ->
        test.ifError err
        test.equal 200, res.statusCode
        test.equal '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>', body
        test.done()

    'should the greetings be invoked': (test) ->
      # given a connected socket.io client
      socket = socketClient.connect "#{rootUrl}/game"

      # then an answer is returned !
      socket.on 'greetings-resp', (err, response) ->
        test.ifError err
        test.equal 'Hi Patrick ! My name is Joe', response
        test.done()

      # when saying hello...
      socket.emit 'greetings', 'Patrick'


    'should the cosultMap be invoked': (test) ->
      # given an item type for characters
      character = new ItemType {name: 'character'}
      character.setProperty 'name', 'string', ''
      character.save (err, saved) ->
        throw new Error err if err?
        character = saved
        # given two characters, jack and john
        new Item({type: character, name: 'Jack', x:0, y:0}).save (err, saved) ->
          throw new Error err if err?
          jack = saved
          new Item({type: character, name: 'John', x:10, y:10}).save (err, saved) ->
            throw new Error err if err?
            john = saved
            # given a connected socket.io client
            socket = socketClient.connect "#{rootUrl}/game"

            # then john and jack are returned
            socket.on 'consultMap-resp', (err, items) ->
              test.ifError err
              test.equal 2, items.length
              test.ok jack.equals items[0]
              test.ok john.equals items[1]
              test.done()

            # when consulting the map
            socket.emit 'consultMap', 0, 0, 10, 10

  tearDown: (end) ->
    server.close()
    end()

