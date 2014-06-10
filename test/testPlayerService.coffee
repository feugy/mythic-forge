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
expect = require('chai').expect
     
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
      expect(player.email).to.equal 'Jack'
      expect(player.password).not.to.exist
      expect(player.password).not.to.equal 'toto'
      expect(player.characters).to.have.lengthOf 0
      done()

  it 'should password be mandatory during registration', (done) ->
    # when registering an account without password
    service.register 'Jack', '', (err, player) ->
      # then an error is returned
      expect(err).to.exist
      expect(err).to.equal 'missingPassword'
      done()

  it 'should email be mandatory during registration', (done) ->
    # when registering an account without email
    service.register '', 'toto', (err, player) ->
      # then an error is returned
      expect(err).to.exist
      expect(err).to.equal 'missingEmail'
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
        expect(err).to.exist
        expect(err).to.include "Email #{player.email} is already used"
        expect(account).to.be.null
        done()
         
    it 'should getByEmail returned player without character resolved', (done) ->
      # when retrieving the player by email
      service.getByEmail player.email, (err, account) ->
        return done "Can't get by email: #{err}" if err?
        # then the player was retrieved
        expect(account).to.exist
        expect(account).to.satisfy (obj) -> player.equals obj
        # then the character was retrievedobj
        expect(account.characters).to.have.lengthOf 1
        expect(account.characters[0]).to.satisfy (obj) -> item2.equals obj
        # then the character linked has not been resolved
        expect(account.characters[0].friends[0]).to.equal item1.id
        done()  
       
    it 'should getByEmail returned player with character resolved', (done) ->
      # when retrieving the player by email
      service.getByEmail player.email, true, (err, account) ->
        return done "Can't get by email: #{err}" if err?
        # then the player was retrieved
        expect(account).to.exist
        expect(account).to.satisfy (obj) -> player.equals 
        # then the character was retrievedobj
        expect(account.characters).to.have.lengthOf 1
        expect(account.characters[0]).to.satisfy (obj) -> item2.equals obj
        # then the character linked has not been resolved
        expect(account.characters[0].friends[0]).to.satisfy (obj) -> item1.equals obj
        done()   

    it 'should getByToken returned player', (done) ->
      # when retrieving the player by token
      service.getByToken token, (err, account) ->
        return done "Can't get by token: #{err}" if err?
        # then the player was retrieved
        expect(account).to.exist
        expect(account).to.satisfy (obj) -> player.equals obj
        # then token changed
        expect(account.token).not.to.equal token
        expect(account.lastConnection.getTime()).to.equal date.getTime()
        token = account.token
        done()

    it 'should getByToken not returned expired player', (done) ->
      # given a expired token
      player.token = token
      player.lastConnection = expiredDate
      player.save (err, saved) ->
        return done err if err?
        player = saved
        service.connectedList = [player.email]

        # when retrieving the player by token
        service.getByToken token, (err) ->
          # then an error is send
          expect(err).to.exist
          expect(err).to.equal 'expiredToken'
          expect(notifications).to.have.lengthOf 1
          expect(notifications[0][0]).to.equal 'disconnect'
          expect(notifications[0][1]).to.satisfy (obj) -> saved.equals obj
          expect(notifications[0][2]).to.equal 'expired'
          # then token was removed in database
          Player.findOne {email:player.email}, (err, saved) ->
            return done err if err?
            expect(saved.token).to.be.null
            done()    

    it 'should not check expiration if not needed', (done) ->
      # given a null expiration period
      original = utils.confKey
      utils.confKey = (args...) -> 
        if args[0] is 'authentication.tokenLifeTime' then 0 else original.apply utils, args
      utils.emit 'confChanged'

      # given a expired token
      player.token = token
      player.lastConnection = expiredDate
      player.save (err, saved) ->
        return done err if err?
        player = saved
        service.connectedList = [player.email]

        # when retrieving the player by token
        service.getByToken token, (err, account) ->
          return done "Can't get by token: #{err}" if err?
          # then the player was retrieved
          expect(account).to.exist
          expect(account).to.satisfy (obj) -> player.equals obj
          # then token changed
          expect(account.token).not.to.equal token
          expect(account.lastConnection.getTime()).to.equal expiredDate
          token = account.token
          # reset previous utility
          utils.confKey = original
          done()

    it 'should disconnect failed on unknown email', (done) ->
      # when retrieving the player by token
      service.disconnect 'toto', '', (err, account) ->
        # then an error is send
        expect(err).to.exist
        expect(err).to.equal 'No player with email toto found'
        done()    

    it 'should disconnect reset token to null', (done) ->
      # given a connected account
      service.connectedList = [player.email]
      # when disconneting the player
      service.disconnect player.email, '', (err, account) ->
        return done "Can't disconnect: #{err}" if err?
        # then the player was returned without token
        expect(account).to.exist
        expect(account).to.satisfy (obj) -> player.equals obj
        # then token changed
        expect(account.token).not.to.exist
        expect(notifications).to.have.lengthOf 1
        expect(notifications).to.deep.equal [['disconnect', account, '']]
        # then token was removed in database
        Player.findOne {email:player.email}, (err, saved) ->
          return done err if err?
          expect(saved.token).to.be.null
          done()    