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
assert = require('chai').assert
     
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
      assert.equal items.length, 1
      assert.ok item1.equals items[0]
      # then only field1 returned
      assert.equal fields.length, 1
      assert.ok field1.equals fields[0]
      done()
        
  it 'should consultMap returned nothing if no item found', (done) ->
    # when retrieving items within coordinate -1:-1 and -5:-5
    service.consultMap map.id, -1, -1, -5, -5, (err, items, fields) ->
      return done "Can't consultMap: #{err}" if err?
      # then no items returned
      assert.equal items.length, 0
      # then no fields returned
      assert.equal fields.length, 0
      done()
        
  it 'should importRules returned nothing', (done) ->
    # when importing rules
    service.importRules (err, rules) ->
      return done "Can't importRules: #{err}" if err?
      # then no rules were exported
      for key of rules
        assert.fail 'no rules may have been returned'
      done()

  it 'should default configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "custom: [1, 15]"}, 'test', (err) ->
      return done err if err?
      # when requesting default configuration
      service.getConf 'root', null, (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        # then the configuration is returned
        assert.equal conf.separator, pathUtils.sep
        assert.equal conf.basePath, 'root/'
        assert.equal conf.apiBaseUrl, 'http://localhost:3080'
        assert.equal conf.imagesUrl, 'http://localhost:3080/images/'
        assert.property conf, 'custom'
        assert.deepEqual conf.custom, [1, 15]
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
          assert.equal conf.separator, pathUtils.sep
          assert.equal conf.basePath, 'root/'
          assert.equal conf.apiBaseUrl, 'http://localhost:3080'
          assert.equal conf.imagesUrl, 'http://localhost:3080/images/'
          assert.equal conf.names.plain, 'plaine'
          assert.equal conf.names.montain, 'montain'
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
            assert.equal conf.separator, pathUtils.sep
            assert.equal conf.basePath, 'root/'
            assert.equal conf.apiBaseUrl, 'http://localhost:3080'
            assert.equal conf.imagesUrl, 'http://localhost:3080/images/'
            assert.equal conf.names.plain, 'dèche'
            assert.equal conf.names.montain, 'montagne'
            assert.equal conf.names.river, 'river'
            assert.equal conf.other, 'WTF'
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
          assert.equal conf.separator, pathUtils.sep
          assert.equal conf.basePath, 'root/'
          assert.equal conf.apiBaseUrl, 'http://localhost:3080'
          assert.equal conf.imagesUrl, 'http://localhost:3080/images/'
          assert.equal conf.names.plain, 'plaine'
          assert.equal conf.names.montain, 'montagne'
          assert.equal conf.names.river, 'river'
          done()

  it 'should unknown locale configuration be accessible', (done) ->
    # given custom configuration options
    adminService.save 'ClientConf', {source: "names:\n  plain: 'plain'"}, 'test', (err) ->
      return done err if err?
      # when requesting default configuration
      service.getConf 'root', 'en', (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        # then the configuration is returned
        assert.equal conf.separator, pathUtils.sep
        assert.equal conf.basePath, 'root/'
        assert.equal conf.apiBaseUrl, 'http://localhost:3080'
        assert.equal conf.imagesUrl, 'http://localhost:3080/images/'
        assert.equal conf.names.plain, 'plain'
        done()

  it 'should invalid yaml not be accepted in configuration', (done) ->
    # when saving an invalid jsonn configuration
    adminService.save 'ClientConf', {source: 'names:\nplain:plain"'}, 'test', (err) ->
      assert.isDefined err
      assert.isNotNull err
      assert.include err.message, 'syntax error'
      #then configuration was not saved
      service.getConf 'root', null, (err, conf) ->
        return done "Can't get configuration: #{err}" if err?
        assert.isUndefined conf.method
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

        assert.lengthOf players, 2

        # then players data are available
        assert.equal players[0].email, 'james'
        assert.equal players[0].firstName, 'Dean'
        assert.equal players[0].lastName, 'James'
        assert.instanceOf players[0].lastConnection, Date
        assert.isTrue players[0].connected
        assert.notProperty players[0], 'password'
        assert.notProperty players[0], 'characters'
        assert.notProperty players[0], 'token'
        assert.notProperty players[0], 'prefs'
        assert.notProperty players[0], 'key'

        assert.equal players[1].email, 'mm'
        assert.equal players[1].firstName, 'Monroe'
        assert.equal players[1].lastName, 'Marylin'
        assert.instanceOf players[1].lastConnection, Date
        assert.isFalse players[1].connected
        assert.notProperty players[1], 'password'
        assert.notProperty players[1], 'characters'
        assert.notProperty players[1], 'token'
        assert.notProperty players[1], 'prefs'
        assert.notProperty players[1], 'key'
        done()