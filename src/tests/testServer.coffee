server = require '../main/web/server'
socketClient = require 'socket.io-client'
Item = require '../main/model/Item'
Map = require '../main/model/Map'
ItemType = require '../main/model/ItemType'
Executable = require '../main/model/Executable'
utils = require '../main/utils'
request = require 'request'
testUtils = require './utils/testUtils'

port = 9090
rootUrl = "http://localhost:#{port}"
character = null
jack = null
john = null
script = null
map = null

module.exports = 

  setUp: (end) ->
    # given a clean ItemTypes and Items collections
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop ->
      # given a working server
      server.listen port, 'localhost', ->
        console.log "test server started on port #{port}"
        end()

  'given a started server': 

    'should the server be responding': (test) ->
      request "#{rootUrl}/konami", (err, res, body) ->
        throw new Error err if err?
        test.equal 200, res.statusCode
        test.equal '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>', body
        test.done()

    'given a map, a type and two characters':
      setUp: (end) ->
        new Map({name: 'server-test'}).save (err, saved) ->
          throw new Error err if err?
          map = saved
          character = new ItemType {name: 'character'}
          character.setProperty 'name', 'string', ''
          character.save (err, saved) ->
            throw new Error err if err?
            character = saved
            # given two characters, jack and john
            new Item({map: map, type: character, name: 'Jack', x:0, y:0}).save (err, saved) ->
              throw new Error err if err?
              jack = saved
              new Item({map: map, type: character, name: 'John', x:10, y:10}).save (err, saved) ->
                throw new Error err if err?
                john = saved
                end()

      'should the consultMap be invoked': (test) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then john and jack are returned
        socket.once 'consultMap-resp', (err, items, fields) ->
          throw new Error err if err?
          test.equal 2, items.length
          test.ok jack.equals items[0]
          test.equal 'Jack', items[0].name
          test.ok john.equals items[1]
          test.equal 'John', items[1].name
          test.done()

        # when consulting the map
        socket.emit 'consultMap', map._id, 0, 0, 10, 10

      'should types be retrieved': (test) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the character type is retrieved
        socket.once 'getTypes-resp', (err, types) ->
          throw new Error err if err?
          test.equal 1, types.length
          test.ok character.get('_id').equals types[0]._id
          test.equal character.get('name'), types[0].name
          test.ok 'name' of types[0].properties
          test.equal character.get('properties').name.type, types[0].properties.name.type
          test.done()

        # when retrieving types by ids
        socket.emit 'getTypes', [character._id]

      'should items be retrieved': (test) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the items are retrieved with their types
        socket.once 'getItems-resp', (err, items) ->
          throw new Error err if err?
          test.equal 2, items.length
          test.ok jack.equals items[0]
          test.equal 'Jack', items[0].name
          test.ok john.equals items[1]
          test.equal 'John', items[1].name
          test.ok character._id.equals items[0].type._id
          test.ok 'name' of items[0].type.properties
          test.equal character.get('properties').name.type, items[0].type.properties.name.type
          test.ok character._id.equals items[1].type._id
          test.ok 'name' of items[1].type.properties
          test.equal character.get('properties').name.type, items[1].type.properties.name.type
          test.done()
          # TODO tests link resolution

        # when retrieving items by ids
        socket.emit 'getItems', [jack._id, john._id]

      'given a rule':
        setUp: (end) ->
          # Empties the compilation and source folders content
          testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
            Executable.resetAll -> 
              script = new Executable 'rename', """Rule = require '../main/model/Rule'
                Item = require '../main/model/Item'

                module.exports = new (class RenameRule extends Rule
                  constructor: ->
                    @name= 'rename'
                  canExecute: (actor, target, callback) =>
                    callback null, target.get('name') is 'Jack'
                  execute: (actor, target, callback) =>
                    @created.push new Item({type: target.type, name:'Peter'})
                    @removed.push actor
                    target.set('name', 'Joe')
                    callback null, 'target renamed'
                )()"""

              script.save (err) ->
                throw new Error err if err?
                end()

        'should executable content be retrieved': (test) ->
          # given a connected socket.io client
          socket = socketClient.connect "#{rootUrl}/game"

          # then the items are retrieved with their types
          socket.once 'getExecutables-resp', (err, executables) ->
            throw new Error err if err?
            test.equal 1, executables.length
            test.equal script._id, executables[0]._id
            test.equal script.content, executables[0].content
            test.done()

          # when retrieving executables
          socket.emit 'getExecutables'       

        'should rule be resolved and executed, and modification propagated': (test) ->
          # given several connected socket.io clients
          socket = socketClient.connect "#{rootUrl}/game"
          socket2 = socketClient.connect "#{rootUrl}/updates"

          # then the rename rule is returned
          socket.once 'resolveRules-resp', (err, results) ->
            throw new Error err if err?
            test.ok jack._id of results
            test.equal 'rename', results[jack._id][0].name

            # then john is renamed in joe
            socket.once 'executeRule-resp', (err, result) ->
              throw new Error err if err?
              test.equal 'target renamed', result
              test.expect 10
              test.done()

            # then an deletion is received for jack
            socket2.once 'deletion', (className, item) ->
              test.equal 'Item', className
              test.ok john.equals item

            # then an creation is received for peter
            socket2.on 'creation', (className, item) ->
              test.equal 'Item', className
              test.equal 'Peter', item.name

            # then an update is received on john's name
            socket2.once 'update', (className, item) ->
              test.ok jack._id.equals item._id
              test.equal 'Item', className
              test.equal 'Joe', item.name

            # when executing the rename rule for john on jack
            socket.emit 'executeRule', results[jack._id][0].name, john._id, jack._id

          # when resolving rules for john on jack
          socket.emit 'resolveRules', john._id, jack._id

  tearDown: (end) ->
    server.close()
    end()