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
service = require('../main/service/PlayerService').get()
assert = require('chai').assert
     
player = null
type = null
item1 = null
item2 = null

describe 'PlayerService tests', ->

  beforeEach (done) ->
    # cleans Players, ItemTypes and Items
    Player.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> 
      # given an item type
      type = new ItemType {name: 'character'}
      type.setProperty 'friends', 'array', 'Item'
      type.save (err, saved) ->
        throw new Error err if err?
        type = saved
        # given two item
        new Item({type: type}).save (err, saved) ->
          throw new Error err if err?
          item1 = saved
          new Item({type: type, friends:[item1]}).save (err, saved) ->
            throw new Error err if err?
            item2 = saved
            done()

  it 'should register creates an account', (done) ->
    # when registering an account with email Jack
    service.register 'Jack', (err, player) ->
      throw new Error "Can't register: #{err}" if err?
      # then a player is returned
      assert.equal 'Jack', player.get 'email'
      assert.equal 0, player.get('characters').length
      done()

  describe 'given an existing player', ->

    beforeEach (done) ->
      new Player({email: 'Joe', characters: [item2]}).save (err, saved) ->
        throw new Error err if err?
        player = saved
        done()
        
    it 'should register failed when reusing email', (done) ->
      # when registering with used email
      service.register player.get('email'), (err, account) ->
        # then an error is triggered
        assert.equal "Email #{player.get 'email'} is already used", err
        assert.ok null is account
        done()
        
    it 'should getByEmail returned player', (done) ->
      # when retrieving the player by email
      service.getByEmail player.get('email'), (err, account) ->
        throw new Error "Can't get by email: #{err}" if err?
        # then the player was retrieved
        assert.ok player.equals account
        assert.equal 1, account.get('characters').length 
        # then the character was retrieved
        assert.ok item2.equals account.get('characters')[0]
        # then the character linked has been resolved
        assert.ok item1.equals account.get('characters')[0].get('friends')[0]
        done()
