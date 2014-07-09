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

Player = require '../hyperion/src/model/Player'
Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
typeFactory = require '../hyperion/src/model/typeFactory'
utils = require '../hyperion/src/util/common'
watcher = require('../hyperion/src/model/ModelWatcher').get()
ObjectId = require('mongodb').BSONPure.ObjectID
{expect} = require 'chai'

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
      expect(className).to.equal 'Player'
      expect(operation).to.equal 'creation'
      expect(instance).to.satisfy (o) -> player.equals o
      # then no password nor token propagated
      expect(instance).not.to.have.property 'password'
      expect(instance).not.to.have.property 'token'
      awaited = true

    # when saving it
    awaited = false
    player.save (err) ->
      return done "Can't save player: #{err}" if err?

      # then it is in mongo
      Player.find {}, (err, docs) ->
        return done "Can't find player: #{err}" if err?
        # then it's the only one document
        expect(docs).to.have.lengthOf 1
        # then it's values were saved
        expect(docs[0]).to.have.property('email').that.is.equal 'Joe'
        expect(docs[0]).to.have.property('password').that.is.not.null
        expect(player.checkPassword 'toto').to.be.true
        expect(docs[0]).to.have.property('characters').that.has.lengthOf 1
        expect(docs[0]).to.have.deep.property('prefs.stuff').that.is.true
        expect(docs[0].characters[0]).to.satisfy (o) -> item.equals o
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

  it 'should invalid json not be accepted in preferences', (done) ->
    watcher.once 'change', (operation, className, instance) -> awaited = true
    awaited = false
    # when saving an invalid json preferences
    new Player({email:'Joey', prefs:'(function(){console.log("hacked !")})()'}).save (err) ->
      expect(err.message).to.include 'syntax error'
      # then it was not saved
      Player.find {}, (err, docs) ->
        return done "Can't find player: #{err}" if err?
        # then no document found
        expect(docs).to.have.lengthOf 0
        expect(awaited, 'watcher was invoked').to.be.false
        done()

  describe 'given a Player', ->

    clearPassword = 'toto'

    beforeEach (done) ->
      player = new Player {email:'Jack', characters:[item], password:clearPassword}
      player.save -> done()

    it 'should player password be checked', (done) ->
      expect(player.checkPassword('titi'), 'incorrect password must not pass').to.be.false
      expect(player.checkPassword(clearPassword), 'correct password must pass').to.be.true
      done()

    it 'should player be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Player'
        expect(operation).to.equal 'deletion'
        expect(instance).to.satisfy (o) -> player.equals o
        awaited = true

      # when removing a player
      awaited = false
      player.remove ->

        # then it's not in mongo anymore
        Player.find {}, (err, docs) ->
          return done "Can't find player: #{err}" if err?
          expect(docs).to.have.lengthOf 0
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should player password be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Player'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> player.equals o
        awaited = true

      # when modifying password and saving a player
      player.password= 'titi'
      awaited = false
      player.save (err, saved) ->
        return done "Can't update player password: #{err}" if err?
        # then password was modified
        expect(saved).to.satisfy (o) -> player.equals o
        expect(player.checkPassword 'titi').to.be.true
        expect(awaited, 'watcher wasn\'t invoked').to.be.true
        done()

    it 'should player be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Player'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> player.equals o
        expect(instance).to.have.property('characters').that.has.lengthOf 0
        awaited = true

      # when modifying and saving a player
      player.characters= []
      awaited = false
      player.save  (err) ->
        return done err if err?
        Player.find {}, (err, docs) ->
          return done "Can't find player: #{err}" if err?
          # then it's the only one document
          expect(docs).to.have.lengthOf 1
          # then only the relevant values were modified
          expect(docs[0]).to.have.property('email').that.is.equal 'Jack'
          expect(docs[0]).to.have.property('characters').that.has.lengthOf 0
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()

    it 'should unknown characters be erased when loading', (done) ->
      # given a unknown character added to player in db
      Player.collection.update {_id:player.id}, {$push: characters:new ObjectId().toString()}, (err) ->
        return done err if err?
        Player.collection.findOne _id: player.id, (err, doc) ->
          return done err if err?
          expect(doc).to.have.property('characters').that.has.lengthOf 2

          # when loading character
          Player.findById player.id, (err, doc) ->
            return done "Can't find player: #{err}" if err?

            # then only the relevant values were modified
            expect(doc).to.have.property('email').that.is.equal 'Jack'
            # then the added unknown character was removed
            expect(doc).to.have.property('characters').that.has.lengthOf 1
            expect(doc.characters[0]).to.satisfy (o) -> item.equals o
            done()

    it 'should unknown characters be erased when saving', (done) ->
      # given a unknown character added to player
      unknown = new ObjectId().toString()
      player.characters.push unknown, item

      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        expect(className).to.equal 'Player'
        expect(operation).to.equal 'update'
        expect(instance).to.satisfy (o) -> player.equals o
        expect(instance).to.have.property('characters').that.has.lengthOf 3
        expect(instance.characters[0]).to.equal item.id
        expect(instance.characters[1]).to.equal unknown
        expect(instance.characters[2]).to.equal item.id
        awaited = true

      # when saving it and retrieving it
      awaited = false
      player.save (err, saved) ->
        return done err if err?
        # then the added unknown character is still here
        expect(saved).to.have.property('characters').that.has.lengthOf 3
        expect(saved.characters[0]).to.satisfy (o) -> item.equals o
        expect(saved.characters[1]).to.equal unknown
        expect(saved.characters[2]).to.satisfy (o) -> item.equals o

        Player.findById player.id, (err, doc) ->
          return done "Can't find player: #{err}" if err?
          # then the added unknown character was removed
          expect(doc).to.have.property('characters').that.has.lengthOf 2
          expect(doc.characters[0]).to.satisfy (o) -> item.equals o
          expect(doc.characters[1]).to.satisfy (o) -> item.equals o
          expect(awaited, 'watcher wasn\'t invoked').to.be.true
          done()