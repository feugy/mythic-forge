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

Player = require '../hyperion/src/model/Player'
Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
typeFactory = require '../hyperion/src/model/typeFactory'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
ObjectId = require('mongodb').BSONPure.ObjectID
assert = require('chai').assert

player = null
item = null
type = null
awaited = false

describe 'Player tests', ->

  before (done) ->
    # given an Item type, an item, and an empty Player collection.
    ItemType.collection.drop -> Player.collection.drop -> ItemType.loadIdCache ->
      new ItemType({id: 'character'}).save (err, saved) ->
        return done err if err?
        type = saved
        Item.collection.drop -> 
          new Item({type: type}).save (err, saved) ->
            return done err if err?
            item = saved
            done()
      
  beforeEach (done) ->
    Player.collection.drop ->  Player.loadIdCache done

  # Restore admin player for further tests
  after (done) ->
    ItemType.collection.drop -> Item.collection.drop -> Item.loadIdCache ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

  it 'should player be created', (done) -> 
    # given a new Player
    player = new Player {email:'Joe', characters:[item], password:'toto', prefs: stuff: true}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Player'
      assert.equal operation, 'creation'
      assert.ok player.equals instance
      # then no password nor token propagated
      assert.isUndefined instance.password
      assert.isUndefined instance.token
      awaited = true

    # when saving it
    awaited = false
    player.save (err) ->
      return done "Can't save player: #{err}" if err?

      # then it is in mongo
      Player.find {}, (err, docs) ->
        return done "Can't find player: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal 'Joe', docs[0].email
        assert.isNotNull docs[0].password
        assert.isTrue player.checkPassword 'toto'
        assert.equal 1, docs[0].characters.length
        assert.isTrue docs[0].prefs.stuff
        assert.ok item.equals docs[0].characters[0]
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should invalid json not be accepted in preferences', (done) ->
    watcher.once 'change', (operation, className, instance) -> awaited = true
    awaited = false
    # when saving an invalid json preferences
    new Player({email:'Joey', prefs:'(function(){console.log("hacked !")})()'}).save (err) ->
      assert.isDefined err
      assert.isNotNull err
      assert.include err, 'syntax error'
      # then it was not saved
      Player.find {}, (err, docs) ->
        return done "Can't find player: #{err}" if err?
        # then no document found
        assert.equal docs.length, 0
        assert.isFalse awaited, 'watcher was invoked'
        done()

  describe 'given a Player', ->

    clearPassword = 'toto'

    beforeEach (done) ->
      player = new Player {email:'Jack', characters:[item], password:clearPassword}
      player.save -> done()

    it 'should player password be checked', (done) ->
      assert.isFalse player.checkPassword('titi'), 'incorrect password must not pass'
      assert.isTrue player.checkPassword(clearPassword), 'correct password must pass'
      done()

    it 'should player be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Player'
        assert.equal operation,'deletion'
        assert.ok player.equals instance
        awaited = true

      # when removing a player
      awaited = false
      player.remove ->

        # then it's not in mongo anymore
        Player.find {}, (err, docs) ->
          return done "Can't find player: #{err}" if err?
          assert.equal 0, docs.length
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should player password be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Player'
        assert.equal operation, 'update'
        assert.ok player.equals instance
        awaited = true

      # when modifying password and saving a player
      player.password= 'titi'
      awaited = false
      player.save (err, saved) ->
        return done "Can't update player password: #{err}" if err?
        # then password was modified
        assert.ok player.equals saved
        assert.isTrue player.checkPassword 'titi'
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

    it 'should player be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Player'
        assert.equal operation, 'update'
        assert.ok player.equals instance
        assert.equal 0, instance.characters.length
        awaited = true

      # when modifying and saving a player
      player.characters= []
      awaited = false
      player.save  (err) ->
        return done err if err?
        Player.find {}, (err, docs) ->
          return done "Can't find player: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal 'Jack', docs[0].email
          assert.equal 0, docs[0].characters.length
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should unknown players be erased when loading', (done) ->
      # given a unknown character added to player in db
      Player.collection.update {_id:player.id}, {$push: characters:new ObjectId().toString()}, (err) ->
        return done err if err?
        Player.collection.findOne _id: player.id, (err, doc) ->
          return done err if err?
          assert.equal doc.characters.length, 2

          # when loading character
          Player.findById player.id, (err, doc) ->
            return done "Can't find player: #{err}" if err?

            # then only the relevant values were modified
            assert.equal 'Jack', doc.email
            # then the added unknown character was removed
            assert.equal 1, doc.characters.length
            assert.ok item.equals, doc.characters[0]
            done()

    it 'should unknown players be erased when saving', (done) ->
      # given a unknown character added to player
      unknown = new ObjectId().toString()
      player.characters.push unknown, item
      player.markModified 'characters'

      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Player'
        assert.equal operation, 'update'
        assert.ok player.equals instance
        assert.equal 3, instance.characters.length
        assert.equal item.id, instance.characters[0]
        assert.equal unknown, instance.characters[1]
        assert.equal item.id, instance.characters[2]
        awaited = true

      # when saving it and retrieving it
      awaited = false
      player.save (err, saved) ->
        return done err if err?
        # then the added unknown character is still here
        assert.equal 3, saved.characters.length
        assert.ok item.equals saved.characters[0]
        assert.equal unknown, saved.characters[1]
        assert.ok item.equals saved.characters[2]

        Player.findById player.id, (err, doc) ->
          return done "Can't find player: #{err}" if err?
          # then the added unknown character was removed
          assert.equal 2, doc.characters.length
          assert.ok item.equals doc.characters[0]
          assert.ok item.equals doc.characters[1]
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()