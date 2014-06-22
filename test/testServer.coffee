###
  Copyright 2010~2014 Damien Feugas
  
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

_ = require 'underscore'
pathUtils = require 'path'
server = require('../hyperion/src/web/middle').server
socketClient = require 'socket.io-client'
Map = require '../hyperion/src/model/Map'
Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
Event = require '../hyperion/src/model/Event'
EventType = require '../hyperion/src/model/EventType'
Executable = require '../hyperion/src/model/Executable'
FSItem = require '../hyperion/src/model/FSItem'
utils = require '../hyperion/src/util/common'
request = require 'request'
fs = require 'fs-extra'
authoringService = require('../hyperion/src/service/AuthoringService').get()
versionService = require('../hyperion/src/service/VersionService').get()
assert = require('chai').assert

port = 9090
rootUrl = "http://localhost:#{port}"
character = null
jack = null
john = null
script = null
map = null
life = null
birth = null
death = null
rid = null

# Generate a unic id for request
# @return a generated id
generateId = -> "req#{Math.floor Math.random()*10000}"

describe 'Server tests', ->

  before (done) ->
    # enforce folders existence
    utils.enforceFolderSync utils.confKey 'game.executable.source'
    utils.enforceFolderSync utils.confKey 'game.client.dev'
    utils.enforceFolderSync utils.confKey 'game.image'
    # given a working server
    server.listen port, 'localhost', done

  after (done) ->
    server.close()
    done()

  describe 'given a started server', ->
    @bail true

    it 'should the server be responding', (done) ->
      request "#{rootUrl}/konami", (err, res, body) ->
        return done err if err?
        assert.equal res.statusCode, 200
        assert.equal body, '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'
        done()

    it 'should file be created, read, moved and removed', (done) ->
      @timeout 4000
      
      # given a connected socket.io client
      socket = socketClient.connect "#{rootUrl}/admin"

      # given a file with binary content
      fs.readFile pathUtils.join(__dirname, 'fixtures', 'image1.png'), (err, imgData) ->
        return done err if err?
        # given a clean root
        versionService.init true, (err) ->
          return done err if err?
          authoringService.init (err) ->
            return done err if err?
            
            file = 
              path: pathUtils.join 'images', 'image1.png'
              isFolder: false
              content: imgData.toString('base64')

            newPath = pathUtils.join 'images', 'image2.png'
            
            # then the saved fsItem is returned
            socket.once 'save-resp', (reqId, err, modelName, saved) ->
              assert.equal rid, reqId
              return done err if err?
              assert.equal modelName, 'FSItem'
              assert.isNotNull saved
              assert.isFalse saved.isFolder
              assert.equal saved.path, file.path
              assert.equal saved.content, file.content

              # then the read fsItem is returned with valid content
              socket.once 'read-resp', (reqId, err, read) ->
                assert.equal rid, reqId
                return done err if err?
                assert.isNotNull read
                assert.isFalse read.isFolder
                assert.equal read.path, file.path
                assert.equal read.content, imgData.toString('base64')

                # then the moved fsItem is returned with valid content
                socket.once 'move-resp', (reqId, err, moved) ->
                  assert.equal rid, reqId
                  return done err if err?
                  assert.isNotNull moved
                  assert.isFalse moved.isFolder
                  assert.equal moved.path, newPath
                  assert.isNull moved.content

                  # then the fsItem was removed
                  socket.once 'remove-resp', (reqId, err, modelName, removed) ->
                    assert.equal rid, reqId
                    return done err if err?
                    assert.equal modelName, 'FSItem'
                    assert.isNotNull removed
                    assert.isFalse removed.isFolder
                    assert.equal removed.path, newPath
                    done()

                  # when removing it
                  rid = generateId()
                  socket.emit 'remove', rid, 'FSItem', moved

                # when moving it
                rid = generateId()
                socket.emit 'move', rid, file, newPath

              # when reading its content
              file.content = null
              rid = generateId()
              socket.emit 'read', rid, file

            # when saving a new file
            rid = generateId()
            socket.emit 'save', rid, 'FSItem', file

    describe 'given a map, an item type, two characters, an event type and two events', ->
      @bail true

      beforeEach (done) ->
        # given a clean ItemTypes and Items collections
        EventType.collection.drop -> Event.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> Map.loadIdCache ->
          new Map(id: 'server-test').save (err, saved) ->
            return done err if err?
            map = saved
            character = new ItemType id: 'character'
            character.setProperty 'name', 'string', ''
            character.save (err, saved) ->
              return done err if err?
              character = saved
              # given two characters, jack and john
              new Item(map: map, type: character, name: 'Jack', x:0, y:0).save (err, saved) ->
                return done err if err?
                jack = saved
                new Item(map: map, type: character, name: 'John', x:10, y:10).save (err, saved) ->
                  return done err if err?
                  john = saved
                  life = new EventType id: 'life'
                  life.setProperty 'step', 'string', 'birth'
                  life.setProperty 'concerns', 'object', 'Item'
                  life.save (err, saved) ->
                    return done err if err?
                    life = saved
                    # given two characters, jack and john
                    new Event(type: life, concerns: jack).save (err, saved) ->
                      return done err if err?
                      birth = saved
                      new Event(type: life, step: 'death', concerns: john).save (err, saved) ->
                        return done err if err?
                        death = saved
                        done()

      it 'should the consultMap be invoked', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then john and jack are returned
        socket.once 'consultMap-resp', (reqId, err, items, fields) ->
          assert.equal rid, reqId
          return done err if err?
          assert.equal items.length, 2
          assert.ok jack.equals items[0]
          assert.equal items[0].name, 'Jack'
          assert.ok john.equals items[1]
          assert.equal items[1].name, 'John'
          done()

        # when consulting the map
        rid = generateId()
        socket.emit 'consultMap', rid, map.id, 0, 0, 10, 10

      it 'should types be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the character type is retrieved
        socket.once 'getTypes-resp', (reqId, err, types) ->
          assert.equal rid, reqId
          return done err if err?
          assert.equal types.length, 2
          for type in types
            awaited = null
            if character.equals type 
              awaited = character
              assert.ok 'name' of type.properties
              assert.equal type.properties.name.type, awaited.properties.name.type
            else if life.equals type
              awaited = life
              assert.ok 'step' of type.properties
              assert.equal type.properties.step.type, awaited.properties.step.type
            else 
              assert.fail "Unknown returned type, #{type}"
            assert.equal type.id, awaited.id
          done()

        # when retrieving types by ids
        rid = generateId()
        socket.emit 'getTypes', rid, [character.id, life.id]

      it 'should items be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the items are retrieved with their types
        socket.once 'getItems-resp', (reqId, err, items) ->
          assert.equal rid, reqId
          return done err if err?
          assert.equal items.length, 2
          assert.ok jack.equals items[0]
          assert.equal items[0]._className, 'Item'
          assert.equal items[0].name, 'Jack'
          assert.ok john.equals items[1]
          assert.equal items[1]._className, 'Item'
          assert.equal items[1].name, 'John'
          assert.equal character.id, items[0].type.id
          assert.ok 'name' of items[0].type.properties
          assert.equal items[0].type.properties.name.type, character.properties.name.type
          assert.equal character.id, items[1].type.id
          assert.ok 'name' of items[1].type.properties
          assert.equal items[1].type.properties.name.type, character.properties.name.type
          done()
          # TODO tests link resolution

        # when retrieving items by ids
        rid = generateId()
        socket.emit 'getItems', rid, [jack.id, john.id]

      it 'should events be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the events are retrieved with their types
        socket.once 'getEvents-resp', (reqId, err, events) ->
          assert.equal rid, reqId
          return done err if err?
          assert.equal events.length, 2
          assert.ok birth.equals events[0]
          assert.equal events[0]._className, 'Event'
          assert.equal events[0].step, 'birth'
          assert.ok death.equals events[1]
          assert.equal events[1]._className, 'Event'
          assert.equal events[1].step, 'death'
          assert.equal life.id, events[0].type.id
          assert.ok 'concerns' of events[0].type.properties
          assert.equal events[0].type.properties.concerns.type, life.properties.concerns.type
          assert.equal life.id, events[1].type.id
          assert.ok 'concerns' of events[1].type.properties
          assert.equal events[1].type.properties.concerns.type, life.properties.concerns.type
          # then their links where resolved
          assert.equal events[0].concerns._className, 'Item'
          assert.ok jack.equals events[0].concerns
          assert.ok character.equals events[0].concerns.type
          assert.equal events[0].concerns.name, 'Jack'
          assert.equal events[1].concerns._className, 'Item'
          assert.ok john.equals events[1].concerns
          assert.ok character.equals events[1].concerns.type
          assert.equal events[1].concerns.name, 'John'
          done()

        # when retrieving events by ids
        rid = generateId()
        socket.emit 'getEvents', rid, [birth.id, death.id]

      describe 'given a rule', ->
        @bail true

        beforeEach (done) ->
          # Empties the compilation and source folders content
          utils.empty utils.confKey('game.executable.source'), (err) -> 
            Executable.resetAll true, (err) -> 
              return done err if err?
              script = new Executable 
                id:'rename', 
                content: """Rule = require 'hyperion/model/Rule'
                  Item = require 'hyperion/model/Item'

                  module.exports = new (class RenameRule extends Rule
                    canExecute: (actor, target, context, callback) =>
                      callback null, if target.name is 'Jack' then [] else null
                    execute: (actor, target, params, context, callback) =>
                      @saved.push new Item({type: target.type, name:'Peter'})
                      @removed.push actor
                      target.name = 'Joe'
                      callback null, 'target renamed'
                  )()"""

              script.save done

        it 'should types be searchable', (done) ->
          # given a connected socket.io client
          socket = socketClient.connect "#{rootUrl}/admin"

          # then the item type and rule were found
          socket.once 'searchTypes-resp', (reqId, err, results) ->
            assert.equal rid, reqId
            return done err if err?
            assert.equal results.length, 2
            tmp = results.filter (obj) -> map.equals obj
            assert.ok tmp.length is 1, 'map was not found'
            tmp = results.filter (obj) -> character.equals obj
            assert.ok tmp.length is 1, 'character was not found'
            done()

          # when searching all types
          rid = generateId()
          socket.emit 'searchTypes', rid, '{"or": [{"id": "/'+map.id+'/i"}, {"id": "'+character.id+'"}]}'

        it 'should executable content be retrieved', (done) ->
          # given a connected socket.io client
          socket = socketClient.connect "#{rootUrl}/game"

          # then the items are retrieved with their types
          socket.once 'getExecutables-resp', (reqId, err, executables) ->
            assert.equal rid, reqId
            return done err if err?
            assert.equal executables.length, 1
            assert.equal executables[0].id, script.id
            assert.equal executables[0].content, script.content
            done()

          # when retrieving executables
          rid = generateId()
          socket.emit 'getExecutables', rid

        it 'should rule be resolved and executed, and modification propagated', (done) ->
          # given several connected socket.io clients
          socket = socketClient.connect "#{rootUrl}/game"
          socket2 = socketClient.connect "#{rootUrl}/updates"

          # then the rename rule is returned
          socket.once 'resolveRules-resp', (reqId, err, results) ->
            assert.equal rid, reqId
            return done err if err?
            assert.property results, 'rename'
            match = (res for res in results when jack.equals res.target)?[0]
            assert.isNotNull match, 'rename does not apply to Jack'

            deleted = false
            created = false
            updated = false
            # then john is renamed in joe
            socket.once 'executeRule-resp', (reqId, err, result) ->
              assert.equal rid, reqId
              return done err if err?
              assert.equal result, 'target renamed'
              setTimeout ->
                assert.ok deleted, 'watcher wasn\'t invoked for deletion'
                assert.ok created, 'watcher wasn\'t invoked for creation'
                assert.ok updated, 'watcher wasn\'t invoked for update'
                done()
              , 1000

            # then an deletion is received for jack
            socket2.once 'deletion', (className, item) ->
              assert.equal className, 'Item'
              assert.ok john.equals item
              deleted = true

            # then an creation is received for peter
            socket2.once 'creation', (className, item) ->
              assert.equal className, 'Item'
              assert.equal item.name, 'Peter'
              created = true

            # then an update is received on john's name
            socket2.once 'update', (className, item) ->
              assert.equal jack.id, item.id
              assert.equal className, 'Item'
              assert.equal item.name, 'Joe'
              updated = true

            # when executing the rename rule for john on jack
            rid = generateId()
            socket.emit 'executeRule', rid, 'rename', john.id, jack.id, {}

          # when resolving rules for john on jack
          rid = generateId()
          socket.emit 'resolveRules', rid, john.id, jack.id, null

    describe 'given a type', ->
      @bail true

      before (done) ->
        ItemType.collection.drop -> utils.empty utils.confKey('game.image'), -> ItemType.loadIdCache ->
          new ItemType(id: 'character').save (err, saved) ->
            return done err if err?
            character = saved
            done()

      it 'should the type be listed', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/admin"

        # then john and jack are returned
        socket.once 'list-resp', (reqId, err, modelName, list) ->
          assert.equal rid, reqId
          return done err if err?
          assert.equal list.length, 1
          assert.equal modelName, 'ItemType'
          assert.ok character.equals list[0]
          done()

        # when consulting the map
          rid = generateId()
        socket.emit 'list', rid, 'ItemType'

      it 'should type image be uploaded and removed', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/admin"

        # given an image
        fs.readFile pathUtils.join(__dirname, 'fixtures', 'image1.png'), (err, data) ->
          return done err if err?

          # then the character type was updated
          socket.once 'uploadImage-resp', (reqId, err, saved) ->
            assert.equal rid, reqId
            return done err if err?
            # then the description image is updated in model
            assert.equal saved.descImage, "#{character.id}-type.png"
            # then the file exists and is equal to the original file
            file = pathUtils.join utils.confKey('game.image'), saved.descImage
            assert.ok fs.existsSync file
            assert.equal fs.readFileSync(file).toString(), data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (reqId, err, saved) ->
              assert.equal rid, reqId
              return done err if err?
              # then the type image is updated in model
              assert.equal saved.descImage, null
              # then the file do not exists anymore
              assert.ok !(fs.existsSync(file))
              done()

            rid = generateId()
            socket.emit 'removeImage', rid, 'ItemType', character.id

          # when saving the type image
          rid = generateId()
          socket.emit 'uploadImage', rid, 'ItemType', character.id, 'png', data.toString('base64')


      it 'should instance image be uploaded and removed', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/admin"

        # given an image
        fs.readFile pathUtils.join(__dirname, 'fixtures', 'image1.png'), (err, data) ->
          return done err if err?

          # then the character type was updated
          socket.once 'uploadImage-resp', (reqId, err, saved) ->
            assert.equal rid, reqId
            return done err if err?
            # then the instance image is updated in model for rank 0
            assert.equal saved.images.length, 1
            assert.equal saved.images[0].file, "#{character.id}-0.png"
            assert.equal saved.images[0].width, 0
            assert.equal saved.images[0].height, 0
            # then the file exists and is equal to the original file
            file = pathUtils.join utils.confKey('game.image'), saved.images[0].file
            assert.ok fs.existsSync file
            assert.equal fs.readFileSync(file).toString(), data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (reqId, err, saved) ->
              assert.equal rid, reqId
              return done err if err?
              # then the instance image is updated in model for rank 0
              assert.equal saved.images.length, 0
              # then the file do not exists anymore
              assert.ok !(fs.existsSync(file))
              done()

            rid = generateId()
            socket.emit 'removeImage', rid, 'ItemType', character.id, 0

          # when saving the instance image #0
          rid = generateId()
          socket.emit 'uploadImage', rid, 'ItemType', character.id, 'png', data.toString('base64'), 0