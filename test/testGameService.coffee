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

fs = require 'fs-extra'
pathUtils = require 'path'
Item = require '../hyperion/src/model/Item'
ItemType = require '../hyperion/src/model/ItemType'
Player = require '../hyperion/src/model/Player'
Map = require '../hyperion/src/model/Map'
Field = require '../hyperion/src/model/Field'
FieldType = require '../hyperion/src/model/FieldType'
ClientConf = require '../hyperion/src/model/ClientConf'
utils = require '../hyperion/src/util/common'
Executable = require '../hyperion/src/model/Executable'
service = require('../hyperion/src/service/GameService').get()
adminService = require('../hyperion/src/service/AdminService').get()
playerService = require('../hyperion/src/service/PlayerService').get()
{expect} = require 'chai'
     
type = null
item1 = null
item2 = null
item3 = null
map = null
field1 = null
field2 = null

describe 'GameService tests', -> 

  beforeEach (done) ->
    # cleans ItemTypes and Items
    utils.empty utils.confKey('game.executable.source'), (err) -> 
      return done err if err?
      Executable.resetAll true, (err) -> 
        return done err if err?
        ItemType.collection.drop -> Item.collection.drop -> Map.collection.drop -> FieldType.collection.drop -> 
        Field.collection.drop -> ClientConf.collection.drop -> Map.loadIdCache ->
          # given a map
          new Map(id: 'test-game').save (err, saved) ->
            return done err if err?
            map = saved
            # given an item type
            type = new ItemType id: 'character'
            type.setProperty 'name', 'string', ''
            type.setProperty 'health', 'integer', 10
            type.save (err, saved) ->
              return done err if err?
              type = saved
              new Item({map: map, type: type, name: 'Jack', x:0, y:0}).save (err, saved) ->
                return done err if err?
                item1 = saved
                new Item({map: map, type: type, name: 'John', x:10, y:10}).save (err, saved) ->
                  return done err if err?
                  item2 = saved
                  new Item({map: map, type: type, name: 'Peter'}).save (err, saved) ->
                    return done err if err?
                    item3 = saved
                    # given a field type
                    new FieldType(id: 'plain').save (err, saved) ->
                      return done err if err?
                      fieldType = saved
                      new Field({mapId:map.id, typeId:fieldType.id, x:5, y:3}).save (err, saved) ->
                        return done err if err?
                        field1 = saved
                        new Field({mapId:map.id, typeId:fieldType.id, x:-2, y:-10}).save (err, saved) ->
                          return done err if err?
                          field2 = saved
                          done()

  after (done) ->
    ClientConf.findOne {_id:'default'}, (err, result) =>
      return done() unless err? or result is null
      # set again the default configuration
      new ClientConf(id: 'default').save done

  it 'should consultMap returned only relevant items', (done) ->
    # when retrieving items within coordinate -5:-5 and 5:5
    service.consultMap map.id, -5, -5, 5, 5, (err, items, fields) ->
      return done "Can't consultMap: #{err}" if err?
      # then only item1 is returned
      expect(items).to.have.lengthOf 1
      expect(item1).to.satisfy (o) -> o.equals items[0]
      # then only field1 returned
      expect(fields).to.have.lengthOf 1
      expect(field1).to.satisfy (o) -> o.equals fields[0]
      done()
        
  it 'should consultMap returned nothing if no item found', (done) ->
    # when retrieving items within coordinate -1:-1 and -5:-5
    service.consultMap map.id, -1, -1, -5, -5, (err, items, fields) ->
      return done "Can't consultMap: #{err}" if err?
      # then no items returned
      expect(items).to.have.lengthOf 0
      # then no fields returned
      expect(fields).to.have.lengthOf 0
      done()
        
  it 'should importRules returned nothing', (done) ->
    # when importing rules
    service.importRules (err, rules) ->
      return done "Can't importRules: #{err}" if err?
      # then no rules were exported
      expect(rules).to.be.empty
      done()

  it 'should default configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "custom: [1, 15]"}, 'test', (err) ->
      return done err if err?
      # when requesting default configuration
      service.getConf 'root', null, (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        # then the configuration is returned
        expect(conf).to.have.property('separator').that.equal pathUtils.sep
        expect(conf).to.have.property('basePath').that.equal 'root/'
        expect(conf).to.have.property('apiBaseUrl').that.equal 'http://localhost:3080'
        expect(conf).to.have.property('imagesUrl').that.equal 'http://localhost:3080/images/'
        expect(conf).to.have.property('gameToken').that.equal 'game.token'
        expect(conf).to.have.property('gameUrl').that.equal 'http://localhost:3080/game'
        expect(conf).to.have.property('custom').that.is.deep.equal [1, 15]
        done()

  it 'should known locale configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "names:\n  plain: 'plain'\n  montain: 'montain'"}, 'test', (err) ->
      return done err if err?
      # given locally overriden custom configuration options
      adminService.save 'ClientConf', {id:'fr', source: "names:\n  plain: 'plaine'"}, 'test', (err) ->
        return done err if err?
        # when requesting default configuration
        service.getConf 'root', 'fr', (err, conf) ->
          return done "Can't get configuration: #{err}" if err?
          # then the configuration is returned
          expect(conf).to.have.property('separator').that.equal pathUtils.sep
          expect(conf).to.have.property('basePath').that.equal 'root/'
          expect(conf).to.have.property('apiBaseUrl').that.equal 'http://localhost:3080'
          expect(conf).to.have.property('imagesUrl').that.equal 'http://localhost:3080/images/'
          expect(conf).to.have.property('gameToken').that.equal 'game.token'
          expect(conf).to.have.property('gameUrl').that.equal 'http://localhost:3080/game'
          expect(conf).to.have.deep.property('names.plain').that.equal 'plaine'
          expect(conf).to.have.deep.property('names.montain').that.equal 'montain'
          done()

  it 'should known sublocale configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "names:\n  plain: 'plain'\n  montain: 'montain'\n  river: 'river'"}, 'test', (err) ->
      return done err if err?
      # given locally overriden custom configuration options
      adminService.save 'ClientConf', {id:'fr', source: "names:\n  plain: 'plaine'\n  montain: 'montagne'"}, 'test', (err) ->
        return done err if err?
        # given sublocally overriden custom configuration options
        adminService.save 'ClientConf', {id:'fr_FR', source: "other: 'WTF'\nnames:\n  plain: 'dèche'"}, 'test', (err) ->
          return done err if err?
          # when requesting default configuration
          service.getConf 'root', 'fr_FR', (err, conf) ->
            return done "Can't get configuration: #{err}" if err?
            # then the configuration is returned
            expect(conf).to.have.property('separator').that.equal pathUtils.sep
            expect(conf).to.have.property('basePath').that.equal 'root/'
            expect(conf).to.have.property('apiBaseUrl').that.equal 'http://localhost:3080'
            expect(conf).to.have.property('imagesUrl').that.equal 'http://localhost:3080/images/'
            expect(conf).to.have.property('gameToken').that.equal 'game.token'
            expect(conf).to.have.property('gameUrl').that.equal 'http://localhost:3080/game'
            expect(conf).to.have.deep.property('names.plain').that.equal 'dèche'
            expect(conf).to.have.deep.property('names.montain').that.equal 'montagne'
            expect(conf).to.have.deep.property('names.river').that.equal 'river'
            expect(conf).to.have.deep.property('other').that.equal 'WTF'
            done()

  it 'should unknown sublocale configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "names:\n  plain: 'plain'\n  montain: 'montain'\n  river: 'river'"}, 'test', (err) ->
      return done err if err?
      # given locally overriden custom configuration options
      adminService.save 'ClientConf', {id:'fr', source: "names:\n  plain: 'plaine'\n  montain: 'montagne'"}, 'test', (err) ->
        return done err if err?
        # when requesting default configuration
        service.getConf 'root', 'fr_BE', (err, conf) ->
          return done "Can't get configuration: #{err}" if err?
          # then the configuration is returned
          expect(conf).to.have.property('separator').that.equal pathUtils.sep
          expect(conf).to.have.property('basePath').that.equal 'root/'
          expect(conf).to.have.property('apiBaseUrl').that.equal 'http://localhost:3080'
          expect(conf).to.have.property('imagesUrl').that.equal 'http://localhost:3080/images/'
          expect(conf).to.have.property('gameToken').that.equal 'game.token'
          expect(conf).to.have.property('gameUrl').that.equal 'http://localhost:3080/game'
          expect(conf).to.have.deep.property('names.plain').that.equal 'plaine'
          expect(conf).to.have.deep.property('names.montain').that.equal 'montagne'
          expect(conf).to.have.deep.property('names.river').that.equal 'river'
          done()

  it 'should unknown locale configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "names:\n  plain: 'plain'"}, 'test', (err) ->
      return done err if err?
      # when requesting default configuration
      service.getConf 'root', 'en', (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        # then the configuration is returned
        expect(conf).to.have.property('separator').that.equal pathUtils.sep
        expect(conf).to.have.property('basePath').that.equal 'root/'
        expect(conf).to.have.property('apiBaseUrl').that.equal 'http://localhost:3080'
        expect(conf).to.have.property('imagesUrl').that.equal 'http://localhost:3080/images/'
        expect(conf).to.have.property('gameToken').that.equal 'game.token'
        expect(conf).to.have.property('gameUrl').that.equal 'http://localhost:3080/game'
        expect(conf).to.have.deep.property('names.plain').that.equal 'plain'
        done()

  it 'should invalid yaml not be accepted in configuration', (done) ->
    # when saving an invalid jsonn configuration
    adminService.save 'ClientConf', {source: 'names:\nplain:plain"'}, 'test', (err) ->
      expect(err).to.have.property('message').that.include 'syntax error'
      # then configuration was not saved
      service.getConf 'root', null, (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        expect(conf).not.to.have.property 'method'
        done()

  describe 'given two players', ->

    before (done) ->
      # given two players
      Player.collection.drop (err)->
        return done err if err?
        new Player(email: 'james', password:'j@m3s', firstName: 'Dean', lastName: 'James', lastConnection: new Date(), characters: ['123456'], token:'a1b2', prefs: hi: 'hello').save (err) ->
          return done err if err?
          new Player(email: 'mm', password:'m@rI', firstName: 'Monroe', lastName: 'Marylin', lastConnection: new Date(), characters: ['789456'], token:'a1b2', prefs: hi: 'Bonjour').save (err) ->
            done err

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should player public data be consulted', (done) ->
      # given an admin player connected
      playerService.connectedList = ['james']

      # when requesting info on these players
      service.getPlayers ['james', 'mm', 'unknown'], (err, players) ->
        return done err if err?

        expect(players).to.have.lengthOf 2

        # then players data are available
        expect(players[0]).to.have.property('email').that.equal 'james'
        expect(players[0]).to.have.property('firstName').that.equal 'Dean'
        expect(players[0]).to.have.property('lastName').that.equal 'James'
        expect(players[0]).to.have.property('lastConnection').that.is.instanceOf Date
        expect(players[0]).to.have.property('connected').that.equal true
        expect(players[0]).not.to.have.property 'password'
        expect(players[0]).not.to.have.property 'characters'
        expect(players[0]).not.to.have.property 'token'
        expect(players[0]).not.to.have.property 'prefs'
        expect(players[0]).not.to.have.property 'key'

        expect(players[1]).to.have.property('email').that.equal 'mm'
        expect(players[1]).to.have.property('firstName').that.equal 'Monroe'
        expect(players[1]).to.have.property('lastName').that.equal 'Marylin'
        expect(players[1]).to.have.property('lastConnection').that.is.instanceOf Date
        expect(players[1]).to.have.property('connected').that.equal false
        expect(players[1]).not.to.have.property 'password'
        expect(players[1]).not.to.have.property 'characters'
        expect(players[1]).not.to.have.property 'token'
        expect(players[1]).not.to.have.property 'prefs'
        expect(players[1]).not.to.have.property 'key'
        done()