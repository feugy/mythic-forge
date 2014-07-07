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
logger = require('../hyperion/src/util/logger').getLogger 'test'
{expect} = require 'chai'

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
        expect(res.statusCode).to.equal 200
        expect(body).to.equal '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'
        done()

    it 'should file be created, read, moved and removed', (done) ->
      @timeout 4000
      
      # given a connected socket.io client
      socket = socketClient.connect "#{rootUrl}/admin"

      # given a file with binary content
      fs.readFile pathUtils.join(__dirname, 'fixtures', 'image1.png'), (err, imgData) ->
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
            expect(rid).to.equal reqId
            return done err if err?
            expect(modelName).to.equal 'FSItem'
            expect(saved).not.to.be.null
            expect(saved).to.have.property('isFolder').that.is.false
            expect(saved).to.have.property('path').that.is.equal file.path
            expect(saved).to.have.property('content').that.is.equal file.content

            # then the read fsItem is returned with valid content
            socket.once 'read-resp', (reqId, err, read) ->
              expect(rid).to.equal reqId
              return done err if err?
              expect(read).not.to.be.null
              expect(read).to.have.property('isFolder').that.is.false
              expect(read).to.have.property('path').that.is.equal file.path
              expect(read).to.have.property('content').that.is.equal imgData.toString 'base64'

              # then the moved fsItem is returned with valid content
              socket.once 'move-resp', (reqId, err, moved) ->
                expect(rid).to.equal reqId
                return done err if err?
                expect(moved).not.to.be.null
                expect(moved).to.have.property('isFolder').that.is.false
                expect(moved).to.have.property('path').that.is.equal newPath
                expect(moved).to.have.property('content').that.is.null

                # then the fsItem was removed
                socket.once 'remove-resp', (reqId, err, modelName, removed) ->
                  expect(rid).to.equal reqId
                  return done err if err?
                  expect(modelName).to.equal 'FSItem'
                  expect(removed).not.to.be.null
                  expect(removed).to.have.property('isFolder').that.is.false
                  expect(removed).to.have.property('path').that.is.equal newPath
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
          expect(rid).to.equal reqId
          return done err if err?
          expect(items).to.have.lengthOf 2
          expect(items[0]).to.satisfy (o) -> jack.equals o
          expect(items[0]).to.have.property('name').that.is.equal 'Jack'
          expect(items[1]).to.satisfy (o) -> john.equals o
          expect(items[1]).to.have.property('name').that.is.equal 'John'
          done()

        # when consulting the map
        rid = generateId()
        socket.emit 'consultMap', rid, map.id, 0, 0, 10, 10

      it 'should types be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the character type is retrieved
        socket.once 'getTypes-resp', (reqId, err, types) ->
          expect(rid).to.equal reqId
          return done err if err?
          expect(types).to.have.lengthOf 2
          for type in types
            awaited = null
            if character.equals type 
              awaited = character
              expect(type).to.have.deep.property('properties.name.type').that.is.equal awaited.properties.name.type
            else if life.equals type
              awaited = life
              expect(type).to.have.deep.property('properties.step.type').that.is.equal awaited.properties.step.type
            else 
              throw new Error "Unknown returned type, #{type}"
            expect(type).to.have.property('id').that.is.equal awaited.id
          done()

        # when retrieving types by ids
        rid = generateId()
        socket.emit 'getTypes', rid, [character.id, life.id]

      it 'should items be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the items are retrieved with their types
        socket.once 'getItems-resp', (reqId, err, items) ->
          expect(rid).to.equal reqId
          return done err if err?
          expect(items).to.have.lengthOf 2
          expect(items[0]).to.satisfy (o) -> jack.equals o
          expect(items[0]).to.have.property('_className').that.is.equal 'Item'
          expect(items[0]).to.have.property('name').that.is.equal 'Jack'
          expect(items[1]).to.satisfy (o) -> john.equals o
          expect(items[1]).to.have.property('_className').that.is.equal 'Item'
          expect(items[1]).to.have.property('name').that.is.equal 'John'
          expect(items[1]).to.have.deep.property('type.id').that.is.equal character.id
          expect(items[0].type).to.have.property('properties').that.have.key 'name'
          expect(items[0]).to.have.deep.property('type.properties.name.type').that.is.equal character.properties.name.type
          expect(items[0]).to.have.deep.property('type.id').that.is.equal character.id
          expect(items[1].type).to.have.property('properties').that.have.key 'name'
          expect(items[1]).to.have.deep.property('type.properties.name.type').that.is.equal character.properties.name.type
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
          expect(rid).to.equal reqId
          return done err if err?
          expect(events).to.have.lengthOf 2
          expect(events[0]).to.satisfy (o) -> birth.equals o
          expect(events[0]).to.have.property('_className').that.is.equal 'Event'
          expect(events[0]).to.have.property('step').that.is.equal 'birth'
          expect(events[1]).to.satisfy (o) -> death.equals o
          expect(events[1]).to.have.property('_className').that.is.equal 'Event'
          expect(events[1]).to.have.property('step').that.is.equal 'death'
          expect(events[1]).to.have.deep.property('type.id').that.is.equal life.id
          expect(events[0]).to.have.deep.property('type.properties.concerns.type').that.is.equal life.properties.concerns.type
          expect(events[0]).to.have.deep.property('type.id').that.is.equal life.id
          expect(events[1]).to.have.deep.property('type.properties.concerns.type').that.is.equal life.properties.concerns.type
          # then their links where resolved
          expect(events[0]).to.have.deep.property('concerns._className').that.is.equal 'Item'
          expect(events[0]).to.have.property('concerns').that.satisfy (o) -> jack.equals o
          expect(events[0]).to.have.deep.property('concerns.type').that.satisfy (o) -> character.equals o
          expect(events[0]).to.have.deep.property('concerns.name').that.is.equal 'Jack'
          expect(events[1]).to.have.deep.property('concerns._className').that.is.equal 'Item'
          expect(events[1]).to.have.property('concerns').that.satisfy (o) -> john.equals o
          expect(events[1]).to.have.deep.property('concerns.type').that.satisfy (o) -> character.equals o
          expect(events[1]).to.have.deep.property('concerns.name').that.is.equal 'John'
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
            expect(rid).to.equal reqId
            return done err if err?
            expect(results).to.have.lengthOf 2
            tmp = results.filter (obj) -> map.equals obj
            expect(tmp, 'map was not found').to.have.lengthOf 1
            tmp = results.filter (obj) -> character.equals obj
            expect(tmp, 'character was not found').to.have.lengthOf 1
            done()

          # when searching all types
          rid = generateId()
          socket.emit 'searchTypes', rid, JSON.stringify or: [{id: map.id}, {id: character.id}]

        it 'should executable content be retrieved', (done) ->
          # given a connected socket.io client
          socket = socketClient.connect "#{rootUrl}/game"

          # then the items are retrieved with their types
          socket.once 'getExecutables-resp', (reqId, err, executables) ->
            expect(rid).to.equal reqId
            return done err if err?
            expect(executables).to.have.lengthOf 1
            expect(executables[0]).to.have.property('id').that.is.equal script.id
            expect(executables[0]).to.have.property('content').that.is.equal script.content
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
            expect(rid).to.equal reqId
            return done err if err?
            expect(results).to.have.property 'rename'
            match = (res for res in results when jack.equals res.target)?[0]
            expect(match, 'rename does not apply to Jack').not.to.be.null

            deleted = false
            created = false
            updated = false
            # then john is renamed in joe
            socket.once 'executeRule-resp', (reqId, err, result) ->
              expect(rid).to.equal reqId
              return done err if err?
              expect(result).to.equal 'target renamed'
              setTimeout ->
                expect(deleted, 'watcher wasn\'t invoked for deletion').to.be.true
                expect(created, 'watcher wasn\'t invoked for creation').to.be.true
                expect(updated, 'watcher wasn\'t invoked for update').to.be.true
                done()
              , 1000

            # then an deletion is received for jack
            socket2.once 'deletion', (className, item) ->
              expect(className).to.equal 'Item'
              expect(item).to.satisfy (o) -> john.equals o
              deleted = true

            # then an creation is received for peter
            socket2.once 'creation', (className, item) ->
              expect(className).to.equal 'Item'
              expect(item).to.have.property('name').that.is.equal 'Peter'
              created = true

            # then an update is received on john's name
            socket2.once 'update', (className, item) ->
              expect(jack).to.have.property('id').that.is.equal item.id
              expect(className).to.equal 'Item'
              expect(item).to.have.property('name').that.is.equal 'Joe'
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
          expect(rid).to.equal reqId
          return done err if err?
          expect(list).to.have.lengthOf 1
          expect(modelName).to.equal 'ItemType'
          expect(list[0]).to.satisfy (o) -> character.equals o
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
            expect(rid).to.equal reqId
            return done err if err?
            # then the description image is updated in model
            expect(saved).to.have.property('descImage').that.is.equal "#{character.id}-type.png"
            # then the file exists and is equal to the original file
            file = pathUtils.join utils.confKey('game.image'), saved.descImage
            expect(fs.existsSync file).to.be.true
            expect(fs.readFileSync(file).toString()).to.equal data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (reqId, err, saved) ->
              expect(rid).to.equal reqId
              return done err if err?
              # then the type image is updated in model
              expect(saved).to.have.property('descImage').that.is.null
              # then the file do not exists anymore
              expect(fs.existsSync file).to.be.false
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
            expect(rid).to.equal reqId
            return done err if err?
            # then the instance image is updated in model for rank 0
            expect(saved).to.have.property('images').that.has.lengthOf 1
            expect(saved.images[0]).to.have.property('file').that.is.equal "#{character.id}-0.png"
            expect(saved.images[0]).to.have.property('width').that.is.equal 0
            expect(saved.images[0]).to.have.property('height').that.is.equal 0
            # then the file exists and is equal to the original file
            file = pathUtils.join utils.confKey('game.image'), saved.images[0].file
            expect(fs.existsSync file).to.be.true
            expect(fs.readFileSync(file).toString()).to.equal data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (reqId, err, saved) ->
              expect(rid).to.equal reqId
              return done err if err?
              # then the instance image is updated in model for rank 0
              expect(saved.images).to.have.lengthOf 0
              # then the file do not exists anymore
              expect(!(fs.existsSync(file))).to.be.true
              done()

            rid = generateId()
            socket.emit 'removeImage', rid, 'ItemType', character.id, 0

          # when saving the instance image #0
          rid = generateId()
          socket.emit 'uploadImage', rid, 'ItemType', character.id, 'png', data.toString('base64'), 0