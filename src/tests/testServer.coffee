server = require '../main/web/server'
socketClient = require 'socket.io-client'
Item = require '../main/model/Item'
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
        throw new Error err if err?
        test.equal 200, res.statusCode
        test.equal '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>', body
        test.done()

    'should the greetings be invoked': (test) ->
      # given a connected socket.io client
      socket = socketClient.connect "#{rootUrl}/game"

      # then an answer is returned !
      socket.once 'greetings-resp', (err, response) ->
        throw new Error err if err?
        test.equal 'Hi Patrick ! My name is Joe', response
        test.done()

      # when saying hello...
      socket.emit 'greetings', 'Patrick'

    'given a type and two characters':
      setUp: (end) ->
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
              end()

      'should the consultMap be invoked': (test) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then john and jack are returned
        socket.once 'consultMap-resp', (err, items) ->
          throw new Error err if err?
          test.equal 2, items.length
          test.ok jack.equals items[0]
          test.ok john.equals items[1]
          test.done()

        # when consulting the map
        socket.emit 'consultMap', 0, 0, 10, 10

      'given a rule':
        setUp: (end) ->
          # Empties the compilation and source folders content
          testUtils.cleanFolder utils.confKey('executable.target'), (err) -> 
            testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
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
              test.expect 7
              test.done()

            # then an deletion is received for jack
            socket2.once 'deletion', (item) ->
              console.log "deletion received for #{item._id}"
              test.ok john.equals item

            # then an creation is received for peter
            socket2.on 'creation', (item) ->
              console.log "creation received for #{item._id}"
              test.equal 'Peter', item.name

            # then an update is received on john's name
            socket2.once 'update', (item) ->
              console.log "update received for #{item._id}"
              test.ok jack._id.equals item._id
              test.equal 'Joe', item.name

            # when executing the rename rule for john on jack
            socket.emit 'executeRule', results[jack._id][0].name, john._id, jack._id

          # when resolving rules for john on jack
          socket.emit 'resolveRules', john._id, jack._id

  tearDown: (end) ->
    server.close()
    end()

