###
  Copyright 2010,2011,2012 Damien Feugas
  
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

fs = require 'fs'
path = require 'path'
server = require '../main/web/server'
socketClient = require 'socket.io-client'
Item = require '../main/model/Item'
Player = require '../main/model/Player'
Map = require '../main/model/Map'
ItemType = require '../main/model/ItemType'
Executable = require '../main/model/Executable'
utils = require '../main/utils'
request = require 'request'
testUtils = require './utils/testUtils'
assert = require('chai').assert

port = 9090
rootUrl = "http://localhost:#{port}"
character = null
jack = null
john = null
script = null
map = null
player = null

describe 'server tests', ->

  before (done) ->
    # given a clean ItemTypes and Items collections
    ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop ->
      # given a working server
      server.listen port, 'localhost', done

  after (done) ->
    server.close()
    done()

  describe 'given a started server', ->

    it 'should the server be responding', (done) ->
      request "#{rootUrl}/konami", (err, res, body) ->
        throw new Error err if err?
        assert.equal res.statusCode, 200
        assert.equal body, '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'
        done()

    describe 'given a map, a type and two characters', ->

      beforeEach (done) ->
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
                done()

      it 'should the consultMap be invoked', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then john and jack are returned
        socket.once 'consultMap-resp', (err, items, fields) ->
          throw new Error err if err?
          assert.equal items.length, 2
          assert.ok jack.equals items[0]
          assert.equal items[0].name, 'Jack'
          assert.ok john.equals items[1]
          assert.equal items[1].name, 'John'
          done()

        # when consulting the map
        socket.emit 'consultMap', map._id, 0, 0, 10, 10

      it 'should types be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the character type is retrieved
        socket.once 'getTypes-resp', (err, types) ->
          throw new Error err if err?
          assert.equal types.length, 1
          assert.ok character.get('_id').equals types[0]._id
          assert.equal types[0]._name.default, character.get('name')
          assert.ok 'name' of types[0].properties
          assert.equal types[0].properties.name.type, character.get('properties').name.type
          done()

        # when retrieving types by ids
        socket.emit 'getTypes', [character._id]

      it 'should items be retrieved', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/game"

        # then the items are retrieved with their types
        socket.once 'getItems-resp', (err, items) ->
          throw new Error err if err?
          assert.equal items.length, 2
          assert.ok jack.equals items[0]
          assert.equal items[0].name, 'Jack'
          assert.ok john.equals items[1]
          assert.equal items[1].name, 'John'
          assert.ok character._id.equals items[0].type._id
          assert.ok 'name' of items[0].type.properties
          assert.equal items[0].type.properties.name.type, character.get('properties').name.type
          assert.ok character._id.equals items[1].type._id
          assert.ok 'name' of items[1].type.properties
          assert.equal items[1].type.properties.name.type, character.get('properties').name.type
          done()
          # TODO tests link resolution

        # when retrieving items by ids
        socket.emit 'getItems', [jack._id, john._id]

      describe 'given a rule', ->

        beforeEach (done) ->
          # Empties the compilation and source folders content
          testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
            Executable.resetAll -> 
              script = new Executable 
                _id:'rename', 
                content: """Rule = require '../main/model/Rule'
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
                done()

        it 'should executable content be retrieved', (done) ->
          # given a connected socket.io client
          socket = socketClient.connect "#{rootUrl}/game"

          # then the items are retrieved with their types
          socket.once 'getExecutables-resp', (err, executables) ->
            throw new Error err if err?
            assert.equal executables.length, 1
            assert.equal executables[0]._id, script._id
            assert.equal executables[0].content, script.content
            done()

          # when retrieving executables
          socket.emit 'getExecutables'       

        it 'should rule be resolved and executed, and modification propagated', (done) ->
          # given several connected socket.io clients
          socket = socketClient.connect "#{rootUrl}/game"
          socket2 = socketClient.connect "#{rootUrl}/updates"

          # then the rename rule is returned
          socket.once 'resolveRules-resp', (err, results) ->
            throw new Error err if err?
            assert.ok jack._id of results
            assert.equal results[jack._id][0].name, 'rename'

            deleted = false
            created = false
            updated = false
            # then john is renamed in joe
            socket.once 'executeRule-resp', (err, result) ->
              throw new Error err if err?
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
              assert.ok jack._id.equals item._id
              assert.equal className, 'Item'
              assert.equal item.name, 'Joe'
              updated = true

            # when executing the rename rule for john on jack
            socket.emit 'executeRule', results[jack._id][0].name, john._id, jack._id

          # when resolving rules for john on jack
          socket.emit 'resolveRules', john._id, jack._id

    describe 'given a player', ->

      beforeEach (done) ->
        Player.collection.drop -> 
          new Player({login:'Léo'}).save (err, saved) ->
            throw new Error err if err?
            player = saved 
            done()

      it 'should player log-in', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/player"

        # then the player is returned
        socket.once 'getByLogin-resp', (err, account) ->
          throw new Error err if err?
          assert.ok player.equals account
          done()

        # when login with the existing account
        socket.emit 'getByLogin', player.get 'login'

      it 'should new player register', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/player"

        # then the player is created
        socket.once 'register-resp', (err, account) ->
          throw new Error err if err?
          assert.equal account.login, 'Loïc'
          assert.ok null is account.character
          done()

        # when creating a new account
        socket.emit 'register', 'Loïc'

    describe 'given a type', ->

      before (done) ->
        ItemType.collection.drop -> testUtils.cleanFolder utils.confKey('images.store'), ->
          new ItemType({name: 'character'}).save (err, saved) ->
            throw new Error err if err?
            character = saved
            done()

      it 'should the type be listed', (done) ->
        # given a connected socket.io client
        socket = socketClient.connect "#{rootUrl}/admin"

        # then john and jack are returned
        socket.once 'list-resp', (err, modelName, list) ->
          throw new Error err if err?
          assert.equal list.length, 1
          assert.equal modelName, 'ItemType'
          assert.ok character.equals list[0]
          done()

        # when consulting the map
        socket.emit 'list', 'ItemType'

      it 'should type image be uploaded and removed', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/admin"

        # given an image
        fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
          throw new Error err if err?

          # then the character type was updated
          socket.once 'uploadImage-resp', (err, saved) ->
            throw new Error err if err?
            # then the description image is updated in model
            assert.equal saved.descImage, "#{character._id}-type.png"
            # then the file exists and is equal to the original file
            file = path.join utils.confKey('images.store'), saved.descImage
            assert.ok fs.existsSync file
            assert.equal fs.readFileSync(file).toString(), data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (err, saved) ->
              throw new Error err if err?
              # then the type image is updated in model
              assert.equal saved.descImage, null
              # then the file do not exists anymore
              assert.ok !(fs.existsSync(file))
              done()

            socket.emit 'removeImage', 'ItemType', character._id

          # when saving the type image
          socket.emit 'uploadImage', 'ItemType', character._id, 'png', data.toString('base64')


      it 'should instance image be uploaded and removed', (done) ->
        # given several connected socket.io clients
        socket = socketClient.connect "#{rootUrl}/admin"

        # given an image
        fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
          throw new Error err if err?

          # then the character type was updated
          socket.once 'uploadImage-resp', (err, saved) ->
            throw new Error err if err?
            # then the instance image is updated in model for rank 0
            assert.equal saved.images.length, 1
            assert.equal saved.images[0].file, "#{character._id}-0.png"
            assert.equal saved.images[0].width, 0
            assert.equal saved.images[0].height, 0
            # then the file exists and is equal to the original file
            file = path.join utils.confKey('images.store'), saved.images[0].file
            assert.ok fs.existsSync file
            assert.equal fs.readFileSync(file).toString(), data.toString()

            # then the character type was updated
            socket.once 'removeImage-resp', (err, saved) ->
              throw new Error err if err?
              # then the instance image is updated in model for rank 0
              assert.equal saved.images.length, 0
              # then the file do not exists anymore
              assert.ok !(fs.existsSync(file))
              done()

            socket.emit 'removeImage', 'ItemType', character._id, 0

          # when saving the instance image #0
          socket.emit 'uploadImage', 'ItemType', character._id, 'png', data.toString('base64'), 0
