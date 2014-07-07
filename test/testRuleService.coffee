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
async = require 'async'
Executable = require '../hyperion/src/model/Executable'
Item = require '../hyperion/src/model/Item'
Event = require '../hyperion/src/model/Event'
Map = require '../hyperion/src/model/Map'
Field = require '../hyperion/src/model/Field'
Player = require '../hyperion/src/model/Player'
ItemType = require '../hyperion/src/model/ItemType'
EventType = require '../hyperion/src/model/EventType'
FieldType = require '../hyperion/src/model/FieldType'
ContactService = require('../hyperion/src/service/ContactService').get()
service = require('../hyperion/src/service/RuleService').get()
notifier = require('../hyperion/src/service/Notifier').get()
utils = require '../hyperion/src/util/common'
{expect} = require 'chai'
 
map= null
map2= null
player= null
type1= null
type2= null
item1= null
item2= null
item3= null
item4= null
event1 = null
field1= null
field2= null
script= null
notifications = []
listener = null

describe 'RuleService tests', ->
  
  beforeEach (done) ->
    notifications = []           
    # given a registered notification listener
    notifier.on notifier.NOTIFICATION, listener = (event, args...) ->
      return unless event is 'turns'
      notifications.push args
    ItemType.collection.drop -> Item.collection.drop ->
      # Empties the compilation and source folders content
      utils.empty utils.confKey('game.executable.source'), (err) -> 
        FieldType.collection.drop -> Field.collection.drop ->
          EventType.collection.drop -> Event.collection.drop ->
            Map.collection.drop -> Map.loadIdCache ->
              map = new Map {id: 'map-Test'}
              map.save (err) ->
                return done err if err?
                map2 = new Map {id: 'map-Test-2'}
                map2.save (err) ->
                  return done err if err?
                  Executable.resetAll true, (err) ->
                    return done err if err?
                    # let workers initialize themselves
                    _.delay done, 100

  afterEach (done) ->
    # remove notifier listeners
    notifier.removeListener notifier.NOTIFICATION, listener
    done()

  it 'should rule create new objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      id:'rule4', 
      content: """Rule = require 'hyperion/model/Rule'
        Item = require 'hyperion/model/Item'
        module.exports = new (class AddPart extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, if actor.stock.length is 0 then [] else null
          execute: (actor, target, params, context, callback) =>
            part = new Item {type:actor.type, name: 'part'}
            @saved.push part
            actor.stock = [part]
            callback null, 'part added'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      type1 = new ItemType id: 'container'
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        return done err if err?
        # given one item
        new Item({type: type1, name:'base'}).save (err, saved) ->
          return done err if err?
          item1 = saved
              
          # given the rules that are applicable for himself
          service.resolve item1.id, item1.id, null, 'admin', (err, results)->
            return done "Unable to resolve rules: #{err}" if err?
            return done 'the rule4 was not resolved' if results['rule4'].length isnt 1

            # when executing this rule on that target
            service.execute 'rule4', item1.id, item1.id, {}, 'admin', (err, result)->
              return done "Unable to execute rules: #{err}" if err?

              # then the rule is executed.
              expect(result).to.equal 'part added'
                # then the item was created on database
              Item.findOne {type: type1.id, name: 'part'}, (err, created) =>
                return done "Item not created" if err? or not(created?)

                # then the container was modified on database
                Item.findOne {type: type1.id, name: 'base'}, (err, existing) =>
                  expect(existing.stock).to.have.lengthOf 1
                  expect(existing.stock[0]).to.equal created.id
                  done()

  it 'should rule delete existing objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      id:'rule5', 
      content: """Rule = require 'hyperion/model/Rule'
        module.exports = new (class RemovePart extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, []
          execute: (actor, target, params, context, callback) =>
            @removed.push target
            callback null, 'part removed'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      new ItemType(
        id: 'container'
        properties: 
          name: 
            type: 'string'
            def: ''
          stock: 
            type: 'array'
            def: 'Item'
          compose:
            type: 'object'
            def: 'Item'
      ).save (err, saved) ->
        return done err if err?
        type1 = saved
        # given two items, the second linked to the first
        new Item(type: type1, name:'part').save (err, saved) ->
          return done err if err?
          item2 = saved
          new Item(type: type1, name:'base', stock:[item2]).save (err, saved) ->
            return done err if err?
            item1 = saved  

            # given the rules that are applicable for the both items
            service.resolve item1.id, item2.id, null, 'admin', (err, results)->
              return done "Unable to resolve rules: #{err}" if err?
              return done 'the rule5 was not resolved' if results['rule5'].length isnt 1

              # when executing this rule on that target
              service.execute 'rule5', item1.id, item2.id, {}, 'admin', (err, result)->
                return done "Unable to execute rules: #{err}" if err?

                # then the rule is executed.
                expect(result).to.equal 'part removed'
                # then the item does not exist in database anymore
                Item.findOne {type: type1.id, name: 'part'}, (err, existing) =>
                  return done "Item not created" if err?

                  expect(existing).to.be.null
                  # then the container does not contain the part
                  Item.findOne {type: type1.id, name: 'base'}, (err, existing) =>
                    return done "Item not created" if err?

                    existing.fetch ->
                      expect(existing.stock).to.have.lengthOf 0
                      done()

  it 'should rule delete existing objects by ids', (done) ->
    # given a rule that creates an object
    script = new Executable
      id:'rule29', 
      content: """Rule = require 'hyperion/model/Rule'
        module.exports = new (class RemovePart extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, []
          execute: (actor, target, params, context, callback) =>
            @removed.push target.id
            callback null, 'removed'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      new ItemType(id: 'container').save (err, saved) ->
        return done err if err?
        type1 = saved
        # given an item
        new Item(type: type1).save (err, saved) ->
          return done err if err?
          Item.findOne {_id: saved.id}, (err, existing) =>
            return done "Unable to create item: #{err}" if err?
            return done 'Item not created' unless existing?

            # given the rules that are applicable for the both items
            service.resolve saved.id, saved.id, null, 'admin', (err, results)->
              return done "Unable to resolve rules: #{err}" if err?
              return done 'the rule29 was not resolved' if results['rule29'].length isnt 1

              # when executing this rule on that target
              service.execute 'rule29', saved.id, saved.id, {}, 'admin', (err, result)->
                return done "Unable to execute rules: #{err}" if err?

                # then the rule is executed.
                expect(result).to.equal 'removed'
                # then the item does not exist in database anymore
                Item.findOne {_id: saved.id}, (err, existing) =>
                  return done "Unable to create item: #{err}" if err?
                  expect(existing).to.be.null
                  done()

  it 'should linked object be modified and saved by a rule', (done) ->
    # given a rule that need links resolution
    script = new Executable 
      id:'rule3', 
      content: """Rule = require 'hyperion/model/Rule'
        class DriveLeft extends Rule
          canExecute: (actor, target, context, callback) =>
            target.fetch ->
              callback null, if target.pilot.equals actor then [] else null
          execute: (actor, target, params, context, callback) =>
            target.fetch ->
              target.x++
              target.pilot.x++
              callback null, 'driven left'
        module.exports = new DriveLeft()"""
    script.save (err) ->
      # given a character type and a car type
      return done err if err?
      type1 = new ItemType id: 'character'
      type1.setProperty 'name', 'string', ''
      type1.save (err, saved) ->
        return done err if err?
        type1 = saved
        type2 = new ItemType id: 'car'
        type2.setProperty 'pilot', 'object', 'Item'
        type2.save (err, saved) ->
          return done err if err?
          type2 = saved
          # given 3 items
          new Item({x:9, y:0, type: type1, name:'Michel Vaillant'}).save (err, saved) ->
            return done err if err?
            item1 = saved
            new Item({x:9, y:0, type: type2, pilot:item1}).save (err, saved) ->
              return done err if err?
              item2 = saved
              
              # given the rules that are applicable for a target 
              service.resolve item1.id, item2.id, null, 'admin', (err, results)->
                return done "Unable to resolve rules: #{err}" if err?
                return done 'the rule3 was not resolved' unless 'rule3' of results

                # when executing this rule on that target
                service.execute 'rule3', item1.id, item2.id, {}, 'admin', (err, result)->
                  return done "Unable to execute rules: #{err}" if err?

                  # then the rule is executed.
                  expect(result).to.equal 'driven left'
                  # then the item was modified on database
                  Item.find {x:10}, (err, items) =>
                    return done "Unable to retrieve items: #{err}" if err?
                    expect(items).to.have.lengthOf 2
                    for item in items
                      expect(item).to.have.property 'x', 10
                    done()

  it 'should linked object (not to actor or target) be modified and saved by a rule', (done) ->
    # given a rule that modifies linked objects
    script = new Executable 
      id:'rule3', 
      content: """Rule = require 'hyperion/model/Rule'
        Item = require 'hyperion/model/Item'

        class ModifyLinked extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, if actor.equals target then [] else null
          execute: (actor, target, params, context, callback) =>
            Item.findCached ['containable_2'], (err, [item]) =>
              return callback err if err?
              item.num = 2;
              @saved.push item
              item.fetch (err, item) =>
                return callback err if err?
                item.content.num = 3;
                callback null
        module.exports = new ModifyLinked()"""
    script.save (err) ->
      return done err if err?
      # given a containable type
      type1 = new ItemType id: 'containable'
      type1.setProperty 'content', 'object', 'Item'
      type1.setProperty 'num', 'integer', 0
      type1.save (err, saved) ->
        return done err if err?
        type1 = saved
        # given 4 items
        new Item({id:'containable_3', type: type1}).save (err, saved) ->
          return done err if err?
          item3 = saved
          new Item({id:'containable_2', type: type1, content: item3}).save (err, saved) ->
            return done err if err?
            item2 = saved
            new Item({id:'containable_1', type: type1, content: item2}).save (err, saved) ->
              return done err if err?
              item1 = saved
              new Item({id:'root', type: type1, content: item1}).save (err, saved) ->
                return done err if err?
                item0 = saved

                # given the rules that are applicable for a target 
                service.resolve item0.id, item0.id, null, 'admin', (err, results)->
                  return done "Unable to resolve rules: #{err}" if err?
                  return done 'the rule3 was not resolved' unless 'rule3' of results

                  # when executing this rule on that target
                  service.execute 'rule3', item0.id, item0.id, {}, 'admin', (err, result)->
                    return done "Unable to execute rules: #{err}" if err?

                    # then the item was modified on database
                    Item.where('num').gte(1).exec (err, items) =>
                      return done "Unable to retrieve items: #{err}" if err?
                      expect(items).to.have.lengthOf 2
                      expect(items[0]).to.have.property 'id', 'containable_3'
                      expect(items[0]).to.have.property 'num', 3
                      expect(items[1]).to.have.property 'id', 'containable_2'
                      expect(items[1]).to.have.property 'num', 2
                      done()
                                 
  describe 'given a player, an event and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      new Executable(
        id:'rule0'
        content:"""Rule = require 'hyperion/model/Rule'
          class MyRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      ).save (err, saved) ->
        # Creates a player
        return done err if err?
        script = saved
        Player.collection.drop ->
          new Player({email: 'Loïc', password:'toto'}).save (err, saved) ->
            return done err if err?
            player = saved
            # Creates an arbitrary script
            new Executable( 
              id:'script1'
              content:"""
                _const = 10
                module.exports = 
                  const: _const
                  _private: -> console.log 'not exported !'
                  add: (a) -> module.exports.const + a
                  _private2: -> # not exported too !
              """
            ).save (err) ->
              return done err if err?
              new EventType(id: 'message').save (err, saved) ->
                return done err if err?
                eventType = saved
                # Drop existing events
                Event.collection.drop -> Event.loadIdCache ->
                  new Event(type: eventType).save (err, saved) ->
                    return done err if err?
                    event1 = saved
                    done()

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should rule be applicable on player', (done) ->
      # when resolving applicable rules for the player
      service.resolve player.id, null, player.email, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        expect(results).to.exist
        # then the rule must have matched
        expect(results).to.have.property 'rule0'
        expect(results.rule0).to.have.lengthOf 1
        expect(results.rule0[0].target).to.satisfy (obj) -> player.equals obj
        done()

    it 'should rule be applicable for player over event', (done) ->
      # when resolving applicable rules for the player
      service.resolve player.id, event1.id, null, player.email, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        expect(results).to.exist
        # then the rule must have matched
        expect(results).to.have.property 'rule0'
        expect(results.rule0).to.have.lengthOf 1
        expect(results.rule0[0].target).to.satisfy (obj) -> event1.equals obj
        done()

    it 'should rule be executed for player', (done) ->
      # given an applicable rule for a target 
      service.resolve player.id, null, player.email, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule0', player.id, {}, player.email, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          expect(result).to.equal 'hello !'
          done()

    it 'should rule be executed for player over event', (done) ->
      # given an applicable rule for a target 
      service.resolve player.id, event1.id, null, player.email, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule0', player.id, event1.id, {}, player.email, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          expect(result).to.equal 'hello !'
          done()

    it 'should rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?

        expect(rules).to.have.property 'rule0'
        rule = rules.rule0

        # then requires have been replaced by a single define
        expect(rule).to.satisfy ((str) -> 0 is str.indexOf "define('rule0', ['hyperion/model/Rule'], function(Rule){\n"), 'no define() call'
        expect(rule.length-3).to.equal rule.indexOf('});'), 'define() not properly closed'
        expect(rule).not.to.contain 'require', 'still require() in rule'
        expect(rule).not.to.contain ' Rule,', 'still scope definition in rule'

        # then module.exports was replaced by return
        expect(rule).not.to.contain 'module.exports =', 'still module.exports'
        
        # then the execute() function isnt available
        expect(rule).not.to.contain 'execute', 'still execute() in rule' 
        expect(rule).not.to.contain 'hello !', 'still execute() code in rule'

        expect(rules).to.have.property 'script1'
        rule = rules.script1

        # then requires have been replaced by a single define
        expect(rule).to.satisfy ((str) -> 0 is str.indexOf 'define(\'script1\', [], function(){\n'), 'no define() call'
        expect(rule.length-3).to.equal rule.indexOf('});'), 'define() not properly closed'
        expect(rule).not.to.contain 'require', 'still require() in script'

        # then module.exports was replaced by return
        expect(rule).not.to.contain 'module.exports =', 'still module.exports'
        
        # then the private code isnt available
        expect(rule).not.to.contain '_private' , 'still private code in script' 
        expect(rule).to.contain '_const = 10', 'missing arbitrary code in script'
        expect(rule).to.contain 'add', 'missing public method code in script'
        done()

    it 'should arbitrary script be exportable to client', (done) ->
      # given an arbitrary script
      script.content = """
        moment = require 'moment'
        _time = null
        module.exports = {
          time: (details) ->
            if details is undefined
              # return set or current time
              if _time? then _time else moment()
            else if details is null
              # reset to current time
              _time = null
              moment()
            else
              # blocks time
              _time = moment details
        }
      """
      script.save (err) ->
        return done err if err?
        # when exporting rules to client
        service.export (err, rules) ->
          return done "Unable to export rules: #{err}" if err?

          expect(rules).to.have.property 'rule0'
          rule = rules.rule0

          # then requires have been replaced by a single define
          expect(rule).to.satisfy ((str) -> 0 is str.indexOf "define('rule0', ['moment'], function(moment){\n"), 'no define() call'
          expect(rule.length-3).to.equal rule.indexOf('});'), 'define() not properly closed'
          expect(rule).not.to.contain 'require', 'still require() in rule'

          # then module.exports was replaced by return
          expect(rule).not.to.contain 'module.exports =', 'still module.exports'
          
          expect(rule.replace /[\n\r]/g, '').to.equal "define('rule0', ['moment'], function(moment){"+
            "var _time;"+
            "_time = null;"+
            "return {"+
            "  time: function(details) {"+
            "    if (details === void 0) {"+
            "      if (_time != null) {"+
            "        return _time;"+
            "      } else {"+
            "        return moment();"+
            "      }"+
            "    } else if (details === null) {"+
            "      _time = null;"+
            "      return moment();"+
            "    } else {"+
            "      return _time = moment(details);"+
            "    }"+
            "  }"+
            "};"+
            "});"
          done()

    it 'should rule be updated and modifications applicable', (done) ->
      # given a modification on rule content
      script.content = """Rule = require 'hyperion/model/Rule'
        class MyRule extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, []
          execute: (actor, target, params, context, callback) =>
            callback null, 'hello modified !'
        module.exports = new MyRule()"""
      script.save (err) ->
        return done err if err?
        # given an applicable rule for a target 
        service.resolve player.id, null, player.email, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          # when executing this rule on that target
          service.execute 'rule0', player.id, {}, player.email, (err, result)->
            return done "Unable to execute rules: #{err}" if err?

            # then the modficiation was taken in account
            expect(result).to.equal 'hello modified !'
            done()

    it 'should current player be injected in canExecute context', (done) ->
      # given a rule matching only on calling player
      script.content = """Rule = require 'hyperion/model/Rule'
        class MyRule extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, if context.player.equals(actor) then [] else null
          execute: (actor, target, params, context, callback) =>
            callback null, context.player
        module.exports = new MyRule()"""
      script.save (err) ->
        return done err if err?

        # when resolving rules on player
        service.resolve player.id, null, player.email, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          expect(results).to.exist
          # then the rule must have matched
          expect(results).to.have.property 'rule0'
          expect(results.rule0).to.have.lengthOf 1
          expect(results.rule0[0].target).to.satisfy (obj) -> player.equals obj
          done()

    it 'should current player be injected in execute context', (done) ->
      # given a rule returning calling player
      script.content = """Rule = require 'hyperion/model/Rule'
        class MyRule extends Rule
          canExecute: (actor, target, context, callback) =>
            callback null, if context.player.equals(actor) then [] else null
          execute: (actor, target, params, context, callback) =>
            callback null, context.player
        module.exports = new MyRule()"""
      script.save (err) ->
        return done err if err?

        # when executing this rule on the player
        service.execute 'rule0', player.id, {}, player.email, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then player returned is calling player
          expect(result).to.satisfy (obj) -> player.equals obj
          done()

  describe 'given items, events, fields and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        id:'rule1', 
        content: """Rule = require 'hyperion/model/Rule'
          class MyRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        new ItemType(
          id: 'spare'
          properties: 
            name: 
              type: 'string'
              def: ''
            parts: 
              type: 'array'
              def: 'Item'
            compose:
              type: 'object'
              def: 'Item'
            notified:
              type: 'boolean'
              def: false
        ).save (err, saved) ->
          return done err if err?
          type1 = saved
          new FieldType(id: 'plain').save (err, saved) ->
            return done err if err?
            fieldType = saved
            new EventType(id: 'communication').save (err, saved) ->
              return done err if err?
              eventType = saved
              # Drop existing events
              Event.collection.drop ->
                new Event(type: eventType).save (err, saved) ->
                  return done err if err?
                  event1 = saved
                  # Drops existing items
                  Item.collection.drop -> Field.collection.drop -> Item.loadIdCache ->
                    # Creates some items
                    new Item(map: map, x:0, y:0, type: type1).save (err, saved) ->
                      return done err if err?
                      item1 = saved
                      new Item(map: map, x:1, y:2, type: type1).save (err, saved) ->
                        return done err if err?
                        item2 = saved
                        new Item(map: map, x:1, y:2, type: type1).save (err, saved) ->
                          return done err if err?
                          item3 = saved
                          new Item(map: map2, x:1, y:2, type: type1).save (err, saved) ->
                            return done err if err?
                            item4 = saved
                            # Creates field
                            new Field(mapId: map.id, typeId: fieldType.id, x:1, y:2).save (err, saved) ->
                              return done err if err?
                              field1 = saved
                              new Field(mapId: map2.id, typeId: fieldType.id, x:1, y:2).save (err, saved) ->
                                return done err if err?
                                field2 = saved
                                done()

    it 'should rule be applicable on empty coordinates', (done) ->
      # when resolving applicable rules at a coordinate with no items
      service.resolve item1.id, -1, 0, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        expect(results).to.exist
        # then the no item found at the coordinate
        expect(results).to.be.empty
        done()

    it 'should rule be applicable on coordinates', (done) ->
      # when resolving applicable rules at a coordinate
      service.resolve item1.id, 1, 2, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        expect(results).to.exist
        # then the dumb rule has only matched objects from the first map
        expect(results).to.have.property 'rule1'
        results = results['rule1']
        expect(results).to.have.lengthOf 3
        # then the dumb rule has matched the second item
        expect(_.find results, (res) -> item2.equals res.target).not.to.be.null
        # then the dumb rule has matched the third item
        expect(_.find results, (res) -> item3.equals res.target).not.to.be.null
        # then the dumb rule has matched the first field
        expect(_.find results, (res) -> field1.equals res.target).not.to.be.null
        done()
        
    it 'should rule be applicable on coordinates with map isolation', (done) ->
      # when resolving applicable rules at a coordinate of the second map
      service.resolve item4.id, 1, 2, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        expect(results).to.exist
        # then the dumb rule has only matched objects from the first map
        expect(results).to.have.property 'rule1'
        results = results['rule1']
        expect(results).to.have.lengthOf 2
        # then the dumb rule has matched the fourth item
        expect(_.find results, (res) -> item4.equals res.target).not.to.be.null
        # then the dumb rule has matched the second field
        expect( _.find results, (res) -> field2.equals res.target).not.to.be.null
        done()

    it 'should rule be applicable on item target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1.id, item2.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        expect(results).to.exist
        # then the dumb rule has matched the second item
        expect(results).to.have.property 'rule1'
        expect(_.find results['rule1'], (res) -> item2.equals res.target).not.to.be.null
        done()

    it 'should rule be executed for item target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1.id, item2.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule1', item1.id, item2.id, {}, 'admin', (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          expect(result).equal 'hello !'
          done()
        
    it 'should rule be applicable on event target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1.id, event1.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        expect(results).to.exist
        # then the dumb rule has matched the second item
        expect(results).to.have.property 'rule1'
        expect(_.find results['rule1'], (res) -> event1.equals res.target).not.to.be.null
        done()

    it 'should rule be executed for event target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1.id, event1.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule1', item1.id, event1.id, {}, 'admin', (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          expect(result).to.equal 'hello !'
          done()
        
    it 'should rule be applicable on field target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1.id, field1.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        expect(results).to.exist
        # then the dumb rule has matched the second item
        expect(results).to.have.property 'rule1'
        expect(_.find results['rule1'], (res) -> field1.equals res.target).not.to.be.null
        done()

    it 'should rule be executed for field target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1.id, field1.id, null, 'admin', (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute 'rule1', item1.id, field1.id, {}, 'admin', (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          expect(result).to.equal 'hello !'
          done()

    it 'should rule execution modifies item in database', (done) ->
      # given a rule that modified coordinates
      script = new Executable
        id:'rule2', 
        content: """Rule = require 'hyperion/model/Rule'
          class MoveRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, if target.x is 1 then [] else null
            execute: (actor, target, params, context, callback) =>
              target.x++
              callback null, 'target moved'
          module.exports = new MoveRule()"""

      script.save (err) ->
        return done err if err?

        # given the rules that are applicable for a target 
        service.resolve item1.id, item2.id, null, 'admin', (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          expect(results).to.have.property 'rule2'
          expect(results.rule2).to.have.lengthOf 1

          # when executing this rule on that target
          service.execute 'rule2', item1.id, item2.id, {}, 'admin', (err, result)->
            return done "Unable to execute rules: #{err}" if err?

            # then the rule is executed.
            expect(result).to.equal 'target moved'
            # then the item was modified on database
            Item.find {x:2}, (err, items) =>
              return done "failed to retrieve items: #{err}" if err?
              expect(items).to.have.lengthOf 1
              expect(items[0]).to.have.property 'x', 2
              done()

    it 'should modification be detected on dynamic attributes', (done) ->
      # given a rule that modified dynamic attributes
      new Executable(
        id:'rule22'
        content: """Rule = require 'hyperion/model/Rule'
          class AssembleRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, if target.type.equals(actor.type) and !target.equals actor then [] else null
            execute: (actor, target, params, context, callback) =>
              target.compose = actor
              actor.parts.push target
              callback null, 'target assembled'
          module.exports = new AssembleRule()"""
      ).save (err) ->
        return done err if err?
        # when executing this rule on that target
        service.execute 'rule22', item1.id, item2.id, {}, 'admin', (err, result)->
          return done "Unable to execute rules: #{err}" if err?
          # then the rule is executed.
          expect(result).to.equal 'target assembled'

          # then the first item was modified on database
          Item.findById item1.id, (err, item) =>
            return done "failed to retrieve item: #{err}" if err?
            expect(item).to.satisfy (obj) -> item1.equals obj
            expect(item.parts).to.have.lengthOf 1
            expect(item.parts[0]).to.equal item2.id, 'item1 do not have item2 in its parts'

            # then the second item was modified on database
            Item.findById item2.id, (err, item) =>
              return done "failed to retrieve item: #{err}" if err?
              expect(item).to.satisfy (obj) -> item2.equals obj
              expect(item.compose).to.equal item1.id, 'item2 do not compose item1'
              done()

    it 'should concurrent modifications on same model be handled', (done) ->
      # given a cyclic objet
      item1.name = 'car'
      item1.parts = [item2, item3]
      item1.save (err, item1) =>
        return done "Unable to link part of item1: #{err}" if err?
        item2.name = 'motor'
        item2.compose = item1
        item2.save (err, item2) =>
          return done "Unable to link part of item2: #{err}" if err?
          item3.name = 'seats'
          item3.compose = item1
          item3.save (err, item3) =>
            return done "Unable to link part of item3: #{err}" if err?
            # given a rule that fetch linked object and modify target in several ways
            new Executable(
              id:'rule35'
              content: """async = require 'async'
                Rule = require 'hyperion/model/Rule'
                class CyclicRule extends Rule
                  canExecute: (actor, target, context, callback) =>
                    callback null, if target in actor.parts then [] else null
                  execute: (actor, target, params, context, callback) =>
                    actor.fetch (err) =>
                      return callback err if err?
                      actor.name += '*'
                      async.each actor.parts, (part, next) =>
                        part.fetch (err) =>
                          return next err if err?
                          part.name += '+'
                          part.compose.name += '!'
                          next()
                      , callback
                module.exports = new CyclicRule()"""
            ).save (err) ->
              return done err if err?
              # when resolving this rule
              service.resolve item1.id, item2.id, 'rule35', 'admin', (err, result) ->
                return done "Unable to reslve rule: #{err}" if err?

                expect(result).to.have.property 'rule35'
                expect(result.rule35).to.have.lengthOf 1
                expect(result.rule35[0].target).to.satisfy (obj) -> item2.equals obj

                # when executing this rule on that target
                service.execute 'rule35', item1.id, item2.id, {}, 'admin', (err, result)->
                  return done "Unable to execute rule: #{err}" if err?
                  # then the rule is executed.
                  
                  # then the first item was modified on database
                  Item.findById item1.id, (err, item) =>
                    return done "failed to retrieve item: #{err}" if err?
                    expect(item.name).to.equal 'car*!!'
                    expect(item.parts).to.have.lengthOf 2
                    expect(item.parts[0]).to.equal item2.id, 'item1 do not have item2 in its parts'
                    expect(item.parts[1]).to.equal item3.id, 'item1 do not have item3 in its parts'

                    # then the second item was modified on database
                    Item.findById item2.id, (err, item) =>
                      return done "failed to retrieve item: #{err}" if err?
                      expect(item.name).to.equal 'motor+'
                      expect(item.compose).to.equal item1.id, 'item2 do not compose item1'

                      # then the third item was modified on database
                      Item.findById item3.id, (err, item) =>
                        return done "failed to retrieve item: #{err}" if err?
                        expect(item.name).to.equal 'seats+'
                        expect(item.compose).to.equal item1.id, 'item3 do not compose item1'
                        done()

    it 'should models methods be forbidden from rules', (done) ->
      # given a rule that tries to save model directly
      new Executable(
        id:'rule37'
        content: """Rule = require 'hyperion/model/Rule'
          class ForbiddenRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              actor.x++;
              actor.save callback
          module.exports = new ForbiddenRule()"""
      ).save (err) ->
        # when executing this rule on that target
        service.execute 'rule37', item1.id, item1.id, {}, 'admin', (err, result)->
          expect(err).to.exist.and.to.include 'denied to executables'
          done()

    it 'should services methods be forbidden from rules', (done) ->
      # given a rule that tries to save model directly
      new Executable(
        id:'rule38'
        content: """Rule = require 'hyperion/model/Rule'
          ContactService = require('hyperion/service/ContactService').get()

          class ForbiddenServiceRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              ContactService.sendTo null, '', callback
          module.exports = new ForbiddenServiceRule()"""
      ).save (err) ->
        # when executing this rule on that target
        service.execute 'rule38', item1.id, item1.id, {}, 'admin', (err, result)->
          expect(err).to.exist.and.to.include 'denied to executables'
          done()

    it 'should query methods be forbidden from rules', (done) ->
      # given a rule that tries to save model directly
      new Executable(
        id:'rule39'
        content: """Rule = require 'hyperion/model/Rule'
          Item = require 'hyperion/model/Item'

          class ForbiddenQueryRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              Item.where('x', actor.x).where('y', actor.y).findOneAndRemove callback
          module.exports = new ForbiddenQueryRule()"""
      ).save (err) ->
        # when executing this rule on that target
        service.execute 'rule39', item1.id, item1.id, {}, 'admin', (err, result)->
          expect(err).to.exist.and.to.include 'denied to executables'
          done()

    it 'should model class methods be forbidden from rules', (done) ->
      # given a rule that tries to save model directly
      new Executable(
        id:'rule40'
        content: """Rule = require 'hyperion/model/Rule'
          Item = require 'hyperion/model/Item'

          class ForbiddenModelClassRule extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              Item.remove actor, callback
          module.exports = new ForbiddenModelClassRule()"""
      ).save (err) ->
        # when executing this rule on that target
        service.execute 'rule40', item1.id, item1.id, {}, 'admin', (err, result)->
          expect(err).to.exist.and.to.include 'denied to executables'
          done()

    describe 'given a mocked ContactService', ->
      originalSendTo = ContactService.sendTo
      sendArgs = []
      sendError = []
      sendReport = []
      invokation = 0

      beforeEach ->
        sendArgs = []
        sendError = []
        sendReport = []
        invokation = 0
        ContactService.sendTo = (args..., callback) ->
          sendArgs[invokation] = args
          callback sendError[invokation], sendReport[invokation++]

      afterEach ->
        ContactService.sendTo = originalSendTo

      it 'should campaign being distinct between turns', (done) ->
        # given a turn rule that send email to same player for different items
        new Executable(
          id:'rule41'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'
            Player = require 'hyperion/model/Player'

            class CampaignRule extends TurnRule
              select: (callback) =>
                Item.find type: "#{type1.id}", notified: false, callback

              execute: (target, callback) =>
                Player.findOne email: 'admin', (err, admin) =>
                  return callback err if err?
                  @sendCampaign players: admin, msg: "message for \#{target.id}"
                  target.notified = true
                  callback null
            module.exports = new CampaignRule()"""
        ).save (err) ->
          Player.findOne email: 'admin', (err, admin) ->
            return done err if err?

            # when triggering turn first time
            service.triggerTurn (err, result)->
              expect(err).not.to.exist
              expect(invokation).to.equal 4

              # then campaign was sent for each item
              for item in [item1, item2, item3, item4]
                found = false
                for [players, msg] in sendArgs when msg is "message for #{item.id}"
                  expect(players, "unexpected player for #{item.id}").to.satisfy (o) -> admin.equals o
                  found = true
                  break
                expect(found, "no campaign found for #{item.id}").to.be.true

              # when triggering turn second time
              service.triggerTurn (err, result)->
                expect(err).not.to.exist
                # then no more campaign was sent
                expect(invokation).to.equal 4
                done()

      it 'should not fail on campaign error', (done) ->
        # given a turn rule that send email to same player for different items
        new Executable(
          id:'rule42'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'
            Player = require 'hyperion/model/Player'

            class SecondCampaignRule extends TurnRule
              select: (callback) =>
                Item.find type: "#{type1.id}", callback

              execute: (target, callback) =>
                Player.findOne email: 'admin', (err, admin) =>
                  return callback err if err?
                  @sendCampaign players: admin, msg: "message for \#{target.id}"
                  callback null
            module.exports = new SecondCampaignRule()"""
        ).save (err) ->
          # given a failing contact service
          sendError = (new Error 'sending problem' for i in [0..3])

          # when triggering turn
          service.triggerTurn (err, result)->
            # no error was sent
            expect(err).not.to.exist

            # then all campaign were issued
            expect(invokation).to.equal 4
            done()

      it 'should campaign being sent during execution', (done) ->
        # given a turn rule that send email to same player for different items
        new Executable(
          id:'rule44'
          content: """Rule = require 'hyperion/model/Rule'

            class SendCampaignRule extends Rule
              canExecute: (player, target, context, callback) =>
                callback null, if player._className is 'Player' then [] else null
              execute: (player, target, params, context, callback) =>
                @sendCampaign players: player, msg: "message for \#{target.id}"
                callback null, null

            module.exports = new SendCampaignRule()"""
        ).save (err) ->
          Player.findOne email: 'admin', (err, admin) ->
            return done err if err?

            # when exeuting rule
            service.execute 'rule44', admin.id, item1.id, {}, 'admin', (err, result)->
              expect(err).not.to.exist
              expect(invokation).to.equal 1
              [player, msg] = sendArgs[0]
              expect(player).to.satisfy (o) -> admin.equals o
              expect(msg).to.equal "message for #{item1.id}" 
              done()

      it 'should campaign not being sent during select', (done) ->
        # given a turn rule that send email to same player for different items
        new Executable(
          id:'rule45'
          content: """Rule = require 'hyperion/model/Rule'

            class IllegalCampaignRule extends Rule
              canExecute: (player, target, context, callback) =>
                @sendCampaign players: player, msg: "message for \#{target.id}"
                callback null, null
              execute: (player, target, params, context, callback) =>
                callback null, null
            module.exports = new IllegalCampaignRule()"""
        ).save (err) ->
          Player.findOne email: 'admin', (err, admin) ->
            return done err if err?

            # when exeuting rule
            service.resolve admin.id, 'rule45', 'admin', (err, result)->
              expect(err).to.include 'only available at execution'
              expect(invokation).to.equal 0
              done()

      it 'should campaign error not fails execution', (done) ->
        # given a turn rule that send email to same player for different items
        new Executable(
          id:'rule46'
          content: """Rule = require 'hyperion/model/Rule'

            class FailingCampaignRule extends Rule
              canExecute: (player, target, context, callback) =>
                callback null, if player._className is 'Player' then [] else null
              execute: (player, target, params, context, callback) =>
                @sendCampaign players: player, msg: "message for \#{target.id}"
                callback null, null

            module.exports = new FailingCampaignRule()"""
        ).save (err) ->
          Player.findOne email: 'admin', (err, admin) ->
            return done err if err?

            # given a failing contact service
            sendError = [new Error 'sending problem']

            # when triggering turn
            service.execute 'rule46', admin.id, item1.id, {}, 'admin', (err, result)->
              # no error was sent
              expect(err).not.to.exist

              # then all campaign were issued
              expect(invokation).to.equal 1
              done()

  describe 'given an item type and an item', ->

    beforeEach (done) ->
      ItemType.collection.drop ->
        Item.collection.drop -> Item.loadIdCache ->
          # given a type
          return done err if err?
          type1 = new ItemType id: 'dog'
          type1.setProperty 'name', 'string', ''
          type1.setProperty 'fed', 'integer', 0
          type1.setProperty 'execution', 'string', ''
          type1.save (err, saved) ->
            return done err if err?
            type1 = saved
            # given two items
            new Item({type: type1, name:'lassie'}).save (err, saved) ->
              return done err if err?
              item1 = saved
              new Item({type: type1, name:'medor'}).save (err, saved) ->
                return done err if err?
                item2 = saved
                done()  

    it 'should turn rule be executed', (done) ->
      # given a turn rule on dogs
      script = new Executable id:'rule6', content: """TurnRule = require 'hyperion/model/TurnRule'
          Item = require 'hyperion/model/Item'

          module.exports = new (class Dumb extends TurnRule
            select: (callback) =>
              Item.find {type: "#{type1.id}"}, callback
            execute: (target, callback) =>
              target.fed++
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then the both dogs where fed
          Item.findOne {type: type1.id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            expect(existing.fed).to.equal 1, 'lassie wasn\'t fed'
         
            Item.findOne {type: type1.id, name: 'medor'}, (err, existing) =>
              return done "Unable to find item: #{err}" if err?
              expect(existing.fed).to.equal 1, 'medor wasn\'t fed'
              done()

    it 'should turn rule be executed in right order', (done) ->
      async.forEach [
        # given a first turn rule on lassie with rank 10
        new Executable id:'rule7', content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank= 10
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                target.fed = 1
                target.execution = target.execution+','+@id
                callback null
            )()"""
      ,
        # given a another turn rule on lassie with rank 1
        new Executable id:'rule8', content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank= 1
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                target.fed = 10
                target.execution = target.execution+','+@id
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 6
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule8']
          expect(notifications[2]).to.deep.equal ['success', 'rule8']
          expect(notifications[3]).to.deep.equal ['rule', 'rule7']
          expect(notifications[4]).to.deep.equal ['success', 'rule7']
          expect(notifications[5]).to.deep.equal ['end']
        
          # then lassie fed status was reseted, and execution order is correct
          Item.findOne {type: type1.id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            expect(existing.execution).to.equal ',rule8,rule7', 'wrong execution order'
            expect(existing.fed).to.equal 1, 'lassie was fed'
            done()

    it 'should turn selection failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken select 
        new Executable
          id:'rule12'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              select: (callback) =>
                callback "selection failure"
              execute: (target, callback) =>
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          id:'rule13'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 6
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule12']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule12']
          expect(notifications[2][2]).to.include 'selection failure'
          expect(notifications[3]).to.deep.equal ['rule', 'rule13']
          expect(notifications[4]).to.deep.equal ['success', 'rule13']
          expect(notifications[5]).to.deep.equal ['end']
          done()

    it 'should turn asynchronous selection failure be reported', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        id:'rule27', 
        content: """TurnRule = require 'hyperion/model/TurnRule'
          Item = require 'hyperion/model/Item'

          module.exports = new (class Dumb extends TurnRule
            select: (callback) =>
              setTimeout => 
                throw new Error @id+' throw error'
              , 5
            execute: (target, callback) =>
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 4
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule27']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule27']
          expect(notifications[2][2]).to.include 'failed to select'
          expect(notifications[3]).to.deep.equal ['end']
          done()

    it 'should turn execution failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken execute 
        new Executable
          id:'rule14'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback 'execution failure'
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          id:'rule15'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                super()
                @rank= 2
              select: (callback) =>
                Item.find {id: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 6
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule14']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule14']
          expect(notifications[2][2]).to.include 'execution failure'
          expect(notifications[3]).to.deep.equal ['rule', 'rule15']
          expect(notifications[4]).to.deep.equal ['success', 'rule15']
          expect(notifications[5]).to.deep.equal ['end']
          done()
        
    it 'should turn asynchronous execution failure be reported', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        id:'rule28', 
        content: """TurnRule = require 'hyperion/model/TurnRule'
          Item = require 'hyperion/model/Item'

          module.exports = new (class Dumb extends TurnRule
            select: (callback) =>
              Item.find {name: 'lassie'}, callback
            execute: (target, callback) =>
              setTimeout => 
                throw new Error @id+' throw error'
              , 5
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 4
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule28']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule28']
          expect(notifications[2][2]).to.include 'failed to select or execute'
          expect(notifications[3]).to.deep.equal ['end']
          done()

    it 'should turn update failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken update 
        new Executable
          id:'rule16'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              select: (callback) =>
                Item.find {name: 'medor'}, callback
              execute: (target, callback) =>
                target.fed = 18
                target.save = (cb) -> cb new Error 'update failure'
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          id:'rule17'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 6
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule16']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule16']
          expect(notifications[2][2]).to.include 'update failure'
          expect(notifications[3]).to.deep.equal ['rule', 'rule17']
          expect(notifications[4]).to.deep.equal ['success', 'rule17']
          expect(notifications[5]).to.deep.equal ['end']
          done()

    it 'should turn compilation failure be reported', (done) ->
      async.forEach [
        # given a turn rule with broken select
        new Executable
          id:'rule18'
          content: """TurnRule = require 'hyperion/model/TurnRule'

            module.exports = new (class Dumb extends TurnRule
              select: (callback) =>
                @error 'coucou'
                callback null
              execute: (target, callback) =>
                callback null
            )()"""
      ,
        # given a correct dumb rule on lassie
        new Executable
          id:'rule19'
          content: """TurnRule = require 'hyperion/model/TurnRule'
            Item = require 'hyperion/model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @rank= 2
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                callback null
            )()"""
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then notifications where received in right order
          expect(notifications).to.have.lengthOf 4
          expect(notifications[0]).to.deep.equal ['begin']
          expect(notifications[1]).to.deep.equal ['rule', 'rule18']
          expect(notifications[2][0..1]).to.deep.equal ['failure', 'rule18']
          expect(notifications[2][2]).to.include 'failed to select or execute rule'
          expect(notifications[3]).to.deep.equal ['end']
          done()

    it 'should disabled turn rule not be executed', (done) ->
      # given a disabled turn rule on lassie
      script = new Executable
        id:'rule9', 
        content: """TurnRule = require 'hyperion/model/TurnRule'
          Item = require 'hyperion/model/Item'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @active = false
            select: (callback) =>
              Item.find {name: "#{item1.name}"}, callback
            execute: (target, callback) =>
              target.fed = -1
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then lassie wasn't fed
          Item.findOne {type: type1.id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            expect(existing.fed).to.equal 0, 'disabled rule was executed'
            done()

    it 'should disabled rule not be resolved nor exported', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        id:'rule10', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @active = false
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              target.name = 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when resolving rule
        service.resolve item1.id, item1.id, null, 'admin', (err, results) ->
          return done "Unable to resolve rules: #{err}" if err?
          # then the rule was not resolved
          expect(results).not.to.have.property 'rule10'
          # then the rule is not exported
          service.export (err, rules) ->
            return done "Unable to export rules: #{err}" if err?
            expect(rules).not.to.have.property 'rule10'
            done()

    it 'should disabled rule not be executed', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        id:'rule11', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @active = false
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              target.name = 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule11', item1.id, item1.id, {}, 'admin', (err, results) ->
          # then the rule was not resolved
          expect(err).to.exist
          expect(err).to.include 'does not apply'
          done()

    it 'should not turn rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?
        expect(rules).to.be.empty
        done()

    it 'should failling rule not be resolved', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        id:'rule20', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              @error 'coucou'
              callback null, []
            execute: (actor, target, params, context, callback) =>
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when resolving rule
        service.resolve item1.id, item1.id, null, 'admin', (err) ->
          # then the error is reported
          expect(err).to.exist
          expect(err).to.include 'has no method'
          done()

    it 'should asynchronous failling rule not be resolved', (done) ->
      # Creates a rule with an asynchronous error in canExecute
      script = new Executable 
        id:'rule25', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              setTimeout => 
                throw new Error @id+' throw error'
              , 5
            execute: (actor, target, params, context, callback) =>
              callback null, null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.resolve item1.id, item1.id, null, 'admin', (err) ->
          # then the error is reported
          expect(err).to.exist
          expect(err).to.include 'rule25 throw error'
          done()

    it 'should failling rule not be executed', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        id:'rule21', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              @error "coucou"
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule21', item1.id, item1.id, {}, 'admin', (err, results) ->
          # then the error is reported
          expect(err).to.exist
          expect(err).to.include 'has no method'
          done()

    it 'should asynchronous failling rule not be executed', (done) ->
      # Creates a rule with an asynchronous error in execute
      script = new Executable 
        id:'rule26', 
        content: """Rule = require 'hyperion/model/Rule'
          
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              setTimeout => 
                throw new Error @id+' throw error'
              , 5
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.execute 'rule26', item1.id, item1.id, {}, 'admin', (err, results) ->
          # then the error is reported
          expect(err).to.exist
          expect(err).to.include 'rule26 throw error'
          done()

    it 'should incorrect parameter rule not be executed', (done) ->
      # Creates a rule with invalid parameter
      script = new Executable 
        id:'rule23', 
        content: """Rule = require 'hyperion/model/Rule'
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, [
                name: 'p1'
                type: 'object'
              ]
            execute: (actor, target, params, context, callback) =>
              callback null
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule23', item1.id, item1.id, {p1: item1}, 'admin', (err, results) ->
          # then the error is reported
          expect(err).to.exist
          expect(err).to.include "missing 'within' constraint"
          done()

    it 'should parameterized rule be executed', (done) ->
      # Creates a rule with valid parameter
      script = new Executable 
        id:'rule24', 
        content: """Rule = require 'hyperion/model/Rule'
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, [
                name: 'p1'
                type: 'object'
                within: [actor, target]
              ]
            execute: (actor, target, params, context, callback) =>
              callback null, params.p1
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing rule
        service.execute 'rule24', item1.id, item1.id, {p1: item1.id}, 'admin', (err, results) ->
          # then no error reported, and parameter was properly used
          return done err if err?
          expect(results).to.equal item1.id
          done()

    it 'should rule affect new items on new maps', (done) ->
      mapId = 'testMap34'
      itemId = 'ralph'
      # given a map that creates a new map and a new item on this map
      script = new Executable
        id: 'rule34'
        content: """Rule = require 'hyperion/model/Rule'
          Map = require 'hyperion/model/Map'
          Item = require 'hyperion/model/Item'
          ItemType = require 'hyperion/model/ItemType'

          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, []
            execute: (actor, target, params, context, callback) =>
              # creates a new map
              map = new Map id:'#{mapId}', kind: 'square'
              @saved.push map

              ItemType.findCached ['dog'], (err, [Dog]) =>
                return callback err if err?
                ralph = new Item id: '#{itemId}', type: Dog, map: map, x: 10, y: 7
                @saved.push ralph
                callback null, 
          )()"""

      script.save (err) ->
        return done err if err?
        # when executing rule
        service.execute 'rule34', item1.id, item1.id, {}, 'admin', (err, results) ->
          # then no error reported
          return done err if err?
          # then map was created
          Map.findCached [mapId], (err, [map]) ->
            return done err if err?
            expect(map).to.exist
            # then item was created
            Item.findCached [itemId], (err, [item]) ->
              return done err if err?
              expect(item).to.exist
              expect(item.type).to.deep.equal type1
              # then item is on map
              expect(item.map).to.deep.equal map
              expect(item).to.have.property 'x', 10
              expect(item).to.have.property 'y', 7
              done()

  describe 'given some dumb rules with categories', ->

    # rule30, rule31: cat1, rule32: cat2, rule33: no category
    beforeEach (done) ->
      async.each [
        new Executable 
          id:'rule30', 
          content: """Rule = require 'hyperion/model/Rule'
            module.exports = new (class Dumb extends Rule
              canExecute: (actor, target, context, callback) =>
                callback null, [] 
              execute: (actor, target, params, context, callback) =>
                callback null, params.p1
            ) 'cat1' """
      ,
        new Executable 
          id:'rule31', 
          content: """Rule = require 'hyperion/model/Rule'
            module.exports = new (class Dumb extends Rule
              canExecute: (actor, target, context, callback) =>
                callback null, [] 
              execute: (actor, target, params, context, callback) =>
                callback null, params.p1
            ) 'cat1' """
      ,
        new Executable 
          id:'rule32', 
          content: """Rule = require 'hyperion/model/Rule'
            module.exports = new (class Dumb extends Rule
              canExecute: (actor, target, context, callback) =>
                callback null, [] 
              execute: (actor, target, params, context, callback) =>
                callback null, params.p1
            ) 'cat2' """
      ,
        new Executable 
          id:'rule33', 
          content: """Rule = require 'hyperion/model/Rule'
            module.exports = new (class Dumb extends Rule
              canExecute: (actor, target, context, callback) =>
                callback null, [] 
              execute: (actor, target, params, context, callback) =>
                callback null, params.p1
            )() """
      ], (script, next) ->
        script.save next
      , (err) ->
        return done err if err?
        new ItemType(id: 'dumber').save (err, saved) ->
          return done err if err?
          itemType = saved
          # Drop existing events
          Item.collection.drop -> Item.loadIdCache ->
            new Item(type: itemType).save (err, saved) ->
              return done err if err?
              item1 = saved
              done()

    it 'should only rules of a given category be resolved', (done) ->
      # when resolving cat2
      service.resolve item1.id, item1.id, ['cat2'], 'admin', (err, results) ->
        # then no error reported
        return done err if err?
        # only rules from cat2 were resolved
        expect(results).not.to.have.property 'rule30'
        expect(results).not.to.have.property 'rule31'
        expect(results).to.have.property 'rule32'
        expect(results).not.to.have.property 'rule33'
        done()

    it 'should rules of a multiple categories be resolved', (done) ->
      # when resolving cat1 and cat2
      service.resolve item1.id, item1.id, ['cat2', 'cat1'], 'admin', (err, results) ->
        # then no error reported
        return done err if err?
        # only rules from cat2 or cat2 were resolved
        expect(results).to.have.property 'rule30'
        expect(results).to.have.property 'rule31'
        expect(results).to.have.property 'rule32'
        expect(results).not.to.have.property 'rule33'
        done()

    it 'should rules without categories be resolved', (done) ->
      # when resolving with empty category
      service.resolve item1.id, item1.id, [''], 'admin', (err, results) ->
        # then no error reported
        return done err if err?
        # only rules without cagegories were resolved
        expect(results).not.to.have.property 'rule30'
        expect(results).not.to.have.property 'rule31'
        expect(results).not.to.have.property 'rule32'
        expect(results).to.have.property 'rule33'
        done()

    it 'should all rules be resolved', (done) ->
      # when resolving without categories
      service.resolve item1.id, item1.id, null, 'admin', (err, results) ->
        # then no error reported
        return done err if err?
        # all rules were resolved
        expect(results).to.have.property 'rule30'
        expect(results).to.have.property 'rule31'
        expect(results).to.have.property 'rule32'
        expect(results).to.have.property 'rule33'
        done()

  describe 'given an item and a parametrized asynchronous rule', ->

    beforeEach (done) ->
      new Executable(
        id:'rule36', 
        content: """Rule = require 'hyperion/model/Rule'
          _ = require 'underscore'
          module.exports = new (class Dumb extends Rule
            canExecute: (actor, target, context, callback) =>
              callback null, [
                {name: 'id', type: 'string'}
                {name: 'delay', type: 'integer'}
              ] 
            execute: (actor, target, params, context, callback) =>
              _.delay =>
                callback null, params.id
              , params.delay
          )()"""
      ).save (err) ->
        return done err if err?
        new ItemType(id: 'dumber').save (err, saved) ->
          return done err if err?
          itemType = saved
          # Drop existing events
          Item.collection.drop -> Item.loadIdCache ->
            new Item(type: itemType).save (err, saved) ->
              return done err if err?
              item1 = saved
              done()

    it 'should two concurrent call not be mixed', (done) ->
      param1 = id: 'request1', delay: 100
      param2 = id: 'request2', delay: 5
      request1 = false
      request2 = false

      service.execute 'rule36', item1.id, item1.id, param1, 'admin', (err, results) ->
        request1 = true
        # then no error is raised, and first id is returned
        expect(err).not.to.exist
        expect(results).to.equal param1.id, "request1 get request2's result back"
        # param1 will be longer than param2
        expect(request2).to.be.true
        done()
      service.execute 'rule36', item1.id, item1.id, param2, 'admin', (err, results) ->
        request2 = true
        # then no error is raised, and second id is returned
        expect(err).not.to.exist
        expect(results).to.equal param2.id, "request 2 get request 1's result back"
        expect(request1).to.be.false