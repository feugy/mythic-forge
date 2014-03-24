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
utils = require '../hyperion/src/util/common'
service = require('../hyperion/src/service/PlayerService').get()
notifier = require('../hyperion/src/service/Notifier').get()
assert = require('chai').assert
     
player = null
type = null
item1 = null
item2 = null
notifications = []
listener = null

describe 'PlayerService tests', ->

  beforeEach (done) ->
    notifications = []
    # cleans Players, ItemTypes and Items
    Player.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> Item.loadIdCache ->
      # given an item type
      type = new ItemType id: 'character'
      type.setProperty 'friends', 'array', 'Item'
      type.save (err, saved) ->
        return done err if err?
        type = saved
        # given two item
        new Item({type: type}).save (err, saved) ->
          return done err if err?
          item1 = saved
          new Item({type: type, friends:[item1]}).save (err, saved) ->
            return done err if err?
            item2 = saved
            # given a registered notification listener
            notifier.on notifier.NOTIFICATION, listener = (event, args...) ->
              return unless event is 'players'
              notifications.push args
            done()

  afterEach (done) ->
    # remove notifier listeners
    notifier.removeListener notifier.NOTIFICATION, listener
    done()

  after (done) ->
    # Restore admin player for further tests
    new Player(email:'admin', password: 'admin', isAdmin:true).save done

  it 'should register creates an account', (done) ->
    # when registering an account with email Jack
    service.register 'Jack', 'toto', (err, player) ->
      return done "Can't register: #{err}" if err?
      # then a player is returned
      assert.equal 'Jack', player.email
      assert.isNotNull player.password
      assert.notEqual 'toto', player.password
      assert.equal 0, player.characters.length
      done()

  it 'should password be mandatory during registration', (done) ->
    # when registering an account without password
    service.register 'Jack', '', (err, player) ->
      # then an error is returned
      assert.isNotNull err
      assert.equal 'Password is mandatory', err, "unexpected error: #{err}"
      done()

  it 'should email be mandatory during registration', (done) ->
    # when registering an account without email
    service.register '', 'toto', (err, player) ->
      # then an error is returned
      assert.isNotNull err
      assert.equal 'Email is mandatory', err, "unexpected error: #{err}"
      done()

  describe 'given an existing player', ->

    token = utils.generateToken 24
    date = new Date()
    expiration = utils.confKey 'authentication.tokenLifeTime'
    expiredDate = new Date().getTime() - (expiration + 1)*1000

    beforeEach (done) ->
      new Player(
        email: 'Joe', 
        characters: [item2]
        token: token
        lastConnection: date
        password: 'toto'
      ).save (err, saved) ->
        return done err if err?
        player = saved
        done()
        
    it 'should register failed when reusing email', (done) ->
      # when registering with used email
      service.register player.email, 'toto', (err, account) ->
        # then an error is triggered
        assert.equal "Email #{player.email} is already used", err
        assert.ok null is account
        done()
         
    it 'should getByEmail returned player without character resolved', (done) ->
      # when retrieving the player by email
      service.getByEmail player.email, (err, account) ->
        return done "Can't get by email: #{err}" if err?
        # then the player was retrieved
        assert.isNotNull account
        assert.ok player.equals account
        assert.equal 1, account.characters.length 
        # then the character was retrieved
        assert.ok item2.equals account.characters[0]
        # then the character linked has not been resolved
        assert.equal item1.id, account.characters[0].friends[0]
        done()  
       
    it 'should getByEmail returned player with character resolved', (done) ->
      # when retrieving the player by email
      service.getByEmail player.email, true, (err, account) ->
        return done "Can't get by email: #{err}" if err?
        # then the player was retrieved
        assert.isNotNull account
        assert.ok player.equals account
        assert.equal 1, account.characters.length 
        # then the character was retrieved
        assert.ok item2.equals account.characters[0]
        # then the character linked has been resolved
        assert.ok item1.equals account.characters[0].friends[0]
        done()   

    it 'should getByToken returned player', (done) ->
      # when retrieving the player by token
      service.getByToken token, (err, account) ->
        return done "Can't get by token: #{err}" if err?
        # then the player was retrieved
        assert.isNotNull account
        assert.ok player.equals account
        # then token changed
        assert.notEqual token, account.token
        assert.equal date.getTime(), account.lastConnection.getTime()
        token = account.token
        done()

    it 'should getByToken not returned expired player', (done) ->
      # given a expired token
      player.token= token
      player.lastConnection= expiredDate
      player.save (err, saved) ->
        return done err if err?
        player = saved
        service.connectedList = [player.email]

        # when retrieving the player by token
        service.getByToken token, (err) ->
          # then an error is send
          assert.isNotNull err
          assert.equal 'expiredToken', err
          assert.equal 1, notifications.length
          assert.equal 'disconnect', notifications[0][0]
          assert.isTrue saved.equals(notifications[0][1]), 'notification do not contains disconnected player'
          # then token was removed in database
          Player.findOne {email:player.email}, (err, saved) ->
            return done err if err?
            assert.isNull saved.token
            done()    

    it 'should disconnect failed on unknown email', (done) ->
      # when retrieving the player by token
      service.disconnect 'toto', '', (err, account) ->
        # then an error is send
        assert.isNotNull err
        assert.equal 'No player with email toto found', err
        done()    

    it 'should disconnect reset token to null', (done) ->
      # given a connected account
      service.connectedList = [player.email]
      # when disconneting the player
      service.disconnect player.email, '', (err, account) ->
        return done "Can't disconnect: #{err}" if err?
        # then the player was returned without token
        assert.isNotNull account
        assert.ok player.equals account
        assert.isNull account.token
        assert.equal 1, notifications.length
        assert.equal 'disconnect', notifications[0][0]
        assert.isTrue account.equals(notifications[0][1]), 'notification do not contains disconnected player'
        # then token was removed in database
        Player.findOne {email:player.email}, (err, saved) ->
          return done err if err?
          assert.isNull saved.token
          done()    