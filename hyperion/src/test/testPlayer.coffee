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

Player = require '../main/model/Player'
Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
watcher = require('../main/model/ModelWatcher').get()
assert = require('chai').assert


player = null
item = null
type = null
awaited = false

describe 'Player tests', ->

  beforeEach (done) ->
    # given an Item type, an item, and an empty Player collection.
    ItemType.collection.drop -> 
      new ItemType({name: 'character'}).save (err, saved) ->
        throw new Error err if err?
        type = saved
        Item.collection.drop -> 
        new Item({type: type}).save (err, saved) ->
          throw new Error err if err?
          item = saved
          Player.collection.drop ->
            done()
      
  afterEach (done) ->
    Player.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> done()

  it 'should player be created', (done) -> 
    # given a new Player
    player = new Player {email:'Joe', characters:[item], password:'toto'}

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
      throw new Error "Can't save player: #{err}" if err?

      # then it is in mongo
      Player.find {}, (err, docs) ->
        throw new Error "Can't find player: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal 'Joe', docs[0].get 'email'
        assert.isNotNull docs[0].get 'password'
        # TODO md5
        assert.equal 1, docs[0].get('characters').length
        assert.ok item.equals docs[0].get('characters')[0]
        assert.ok awaited, 'watcher wasn\'t invoked'
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
          throw new Error "Can't find player: #{err}" if err?
          assert.equal 0, docs.length
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    #TODO it 'should player password be updated'

    it 'should player be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Player'
        assert.equal operation, 'update'
        assert.ok player.equals instance
        assert.equal 0, instance.characters.length
        awaited = true

      # when modifying and saving a player
      player.set 'characters', []
      awaited = false
      player.save ->

        Player.find {}, (err, docs) ->
          throw new Error "Can't find player: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal 'Jack', docs[0].get 'email'
          assert.equal 0, docs[0].get('characters').length
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()