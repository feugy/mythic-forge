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

testUtils = require './utils/testUtils'
Executable = require '../src/model/Executable'
Item = require '../src/model/Item'
Map = require '../src/model/Map'
Field = require '../src/model/Field'
Player = require '../src/model/Player'
ItemType = require '../src/model/ItemType'
FieldType = require '../src/model/FieldType'
service = require('../src/service/RuleService').get()
utils = require '../src/utils'
assert = require('chai').assert
 
map= null
player= null
type1= null
type2= null
item1= null
item2= null
item3= null
field1= null
script= null

describe 'RuleService tests', ->

  beforeEach (done) ->
    ItemType.collection.drop -> Item.collection.drop ->
      # Empties the compilation and source folders content
      testUtils.cleanFolder utils.confKey('executable.source'), (err) -> 
        Executable.resetAll -> 
          Field.collection.drop ->
            Map.collection.drop ->
              map = new Map {name: 'map-Test'}
              map.save -> done()

  it 'should linked object be modified and saved by a rule', (done) ->
    # given a rule that need links resolution
    script = new Executable 
      _id:'rule3', 
      content: """Rule = require '../model/Rule'
        class DriveLeft extends Rule
          constructor: ->
            @name= 'rule 3'
          canExecute: (actor, target, callback) =>
            target.getLinked ->
              callback null, target.get('pilot').equals actor
          execute: (actor, target, callback) =>
            target.getLinked ->
              target.x++
              target.get('pilot').x++
              callback null, 'driven left'
        module.exports = new DriveLeft()"""
    script.save (err) ->
      # given a character type and a car type
      return done err if err?
      type1 = new ItemType({name: 'character'})
      type1.setProperty 'name', 'string', ''
      type1.save (err, saved) ->
        return done err if err?
        type1 = saved
        type2 = new ItemType({name: 'car'})
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
              service.resolve item1._id, item2._id, (err, results)->
                return done "Unable to resolve rules: #{err}" if err?
                return done 'the rule 3 was not resolved' if results[item2._id].length isnt 1

                # when executing this rule on that target
                service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
                  return done "Unable to execute rules: #{err}" if err?

                  # then the rule is executed.
                  assert.equal result, 'driven left'
                  # then the item was modified on database
                  Item.find {x:10}, (err, items) =>
                    return done "Unable to retrieve items: #{err}" if err?
                    assert.equal 2, items.length
                    assert.equal 10, items[0].x
                    assert.equal 10, items[0].x
                    done()

  it 'should rule create new objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      _id:'rule4', 
      content: """Rule = require '../model/Rule'
        Item = require '../model/Item'
        module.exports = new (class AddPart extends Rule
          constructor: ->
            @name= 'rule 4'
          canExecute: (actor, target, callback) =>
            callback null, actor.get('stock').length is 0
          execute: (actor, target, callback) =>
            part = new Item {type:actor.type, name: 'part'}
            @created.push part
            actor.set 'stock', [part]
            callback null, 'part added'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      type1 = new ItemType({name: 'container'})
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        # given one item
        new Item({type: type1, name:'base'}).save (err, saved) ->
          return done err if err?
          item1 = saved
              
          # given the rules that are applicable for himself
          service.resolve item1._id, item1._id, (err, results)->
            return done "Unable to resolve rules: #{err}" if err?
            return done 'the rule 4 was not resolved' if results[item1._id].length isnt 1

            # when executing this rule on that target
            service.execute results[item1._id][0].name, item1._id, item1._id, (err, result)->
              return done "Unable to execute rules: #{err}" if err?

              # then the rule is executed.
              assert.equal result, 'part added'
                # then the item was created on database
              Item.findOne {type: type1._id, name: 'part'}, (err, created) =>
                return done "Item not created" if err? or not(created?)

                # then the container was modified on database
                Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                  assert.equal 1, existing.get('stock').length
                  assert.ok created._id.equals existing.get('stock')[0]
                  done()

  it 'should rule delete existing objects', (done) ->
    # given a rule that creates an object
    script = new Executable
      _id:'rule5', 
      content: """Rule = require '../model/Rule'
        module.exports = new (class RemovePart extends Rule
          constructor: ->
            @name= 'rule 5'
          canExecute: (actor, target, callback) =>
            callback null, (part for part in actor.get('stock') when target.equals(part))?
          execute: (actor, target, callback) =>
            @removed.push target
            callback null, 'part removed'
        )()"""
    script.save (err) ->
      # given a type
      return done err if err?
      type1 = new ItemType({name: 'container'})
      type1.setProperty 'name', 'string', ''
      type1.setProperty 'stock', 'array', 'Item'
      type1.save (err, saved) ->
        # given two items, the second linked to the first
        new Item({type: type1, name:'part'}).save (err, saved) ->
          return done err if err?
          item2 = saved
          new Item({type: type1, name:'base', stock:[item2]}).save (err, saved) ->
            return done err if err?
            item1 = saved  

            # given the rules that are applicable for the both items
            service.resolve item1._id, item2._id, (err, results)->
              return done "Unable to resolve rules: #{err}" if err?
              return done 'the rule 5 was not resolved' if results[item2._id].length isnt 1

              # when executing this rule on that target
              service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
                return done "Unable to execute rules: #{err}" if err?

                # then the rule is executed.
                assert.equal result, 'part removed'
                # then the item does not exist in database anymore
                Item.findOne {type: type1._id, name: 'part'}, (err, existing) =>
                  return done "Item not created" if err?

                  assert.ok existing is null
                  # then the container does not contain the part
                  Item.findOne {type: type1._id, name: 'base'}, (err, existing) =>
                    return done "Item not created" if err?

                    existing.getLinked ->
                      assert.equal 1, existing.get('stock').length
                      assert.equal null, existing.get('stock')[0]
                      done()

  describe 'given a player and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule0'
        content:"""Rule = require '../model/Rule'
          class MyRule extends Rule
            constructor: ->
              @name= 'rule 0'
            canExecute: (actor, target, callback) =>
              callback null, true;
            execute: (actor, target, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      script.save (err, saved) ->
        # Creates a type
        return done err if err?
        script = saved
        Player.collection.drop ->
          new Player({email: 'Loïc', password:'toto'}).save (err, saved) ->
            return done err if err?
            player = saved
            done()

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should rule be applicable on player', (done) ->
      # when resolving applicable rules for the player
      service.resolve player._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the rule must have matched
        assert.ok player._id of results
        assert.equal 1, results[player._id].length
        assert.equal 'rule 0', results[player._id][0].name 
        done()

    it 'should rule be executed for player', (done) ->
      # given an applicable rule for a target 
      service.resolve player._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute results[player._id][0].name, player._id, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()

    it 'should rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?

        assert.ok 'rule0' of rules
        rule = rules.rule0

        # then requires have been replaced by a single define
        assert.equal 0, rule.indexOf('define(\'rule0\', [\'model/Rule\'], function(Rule){\n'), 'no define() call'
        assert.equal rule.length-3, rule.indexOf('});'), 'define() not properly closed'
        assert.equal -1, rule.indexOf('require'), 'still require() in rule'
        assert.equal -1, rule.indexOf(' Rule,'), 'still scope definition in rule'

        # then module.exports was replaced by return
        assert.equal -1, rule.indexOf('module.exports ='), 'still module.exports'
        
        # then the execute() funciton isnt available
        assert.equal -1, rule.indexOf('execute'), 'still execute() in rule' 
        assert.equal -1, rule.indexOf('hello !'), 'still execute() code in rule'
        done()

    it 'should rule be updated and modifications applicable', (done) ->
      # given a modification on rule content
      script.content = """Rule = require '../model/Rule'
        class MyRule extends Rule
          constructor: ->
            @name= 'rule 0'
          canExecute: (actor, target, callback) =>
            callback null, true;
          execute: (actor, target, callback) =>
            callback null, 'hello modified !'
        module.exports = new MyRule()"""
      script.save (err) ->
        return done err if err?
        # given an applicable rule for a target 
        service.resolve player._id, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          # when executing this rule on that target
          service.execute results[player._id][0].name, player._id, (err, result)->
            return done "Unable to execute rules: #{err}" if err?

            # then the modficiation was taken in account
            assert.equal result, 'hello modified !'
            done()

  describe 'given 3 items and a dumb rule', ->

    beforeEach (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule1', 
        content: """Rule = require '../model/Rule'
          class MyRule extends Rule
            constructor: ->
              @name= 'rule 1'
            canExecute: (actor, target, callback) =>
              callback null, true;
            execute: (actor, target, callback) =>
              callback null, 'hello !'
          module.exports = new MyRule()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        new ItemType({name: 'character'}).save (err, saved) ->
          return done err if err?
          type1 = saved
          new FieldType({name: 'plain'}).save (err, saved) ->
            return done err if err?
            fieldType = saved
            # Drops existing items
            Item.collection.drop -> Field.collection.drop ->
              # Creates 3 items
              new Item({map: map, x:0, y:0, type: type1}).save (err, saved) ->
                return done err if err?
                item1 = saved
                new Item({map: map, x:1, y:2, type: type1}).save (err, saved) ->
                  return done err if err?
                  item2 = saved
                  new Item({map: map, x:1, y:2, type: type1}).save (err, saved) ->
                    return done err if err?
                    item3 = saved
                    # Creates a field
                    new Field({mapId: map._id, typeId: fieldType._id, x:1, y:2}).save (err, saved) ->
                      return done err if err?
                      field1 = saved
                      done()

    it 'should rule be applicable on empty coordinates', (done) ->
      # when resolving applicable rules at a coordinate with no items
      service.resolve item1._id, -1, 0, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the no item found at the coordinate
        for key of results 
          assert.fail 'results are not empty'
        done()

    it 'should rule be applicable on coordinates', (done) ->
      # when resolving applicable rules at a coordinate
      service.resolve item1._id, 1, 2, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        assert.ok item2._id of results, 'The item2\'s id is not in results'
        match = results[item2._id]
        assert.equal 1, match.length
        assert.equal 'rule 1', match[0]?.name
        # then the dumb rule has matched the third item
        assert.ok item3._id of results, 'The item3\'s id is not in results'
        match = results[item3._id]
        assert.equal 1, match.length
        assert.equal 'rule 1', match[0]?.name
        # then the dumb rule has matched the field
        assert.ok field1._id of results, 'The field1\'s id is not in results'
        match = results[field1._id]
        assert.equal 1, match.length
        assert.equal 'rule 1', match[0]?.name
        done()
        
    it 'should rule be applicable on target', (done) ->
      # when resolving applicable rules for a target
      service.resolve item1._id, item2._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?
         
        assert.ok results isnt null and results isnt undefined
        # then the dumb rule has matched the second item
        assert.ok item2._id of results, 'The item2\'s id is not in results'
        match = results[item2._id]
        assert.equal 1, match.length
        assert.equal 'rule 1', match[0]?.name
        done()

    it 'should rule be executed for target', (done) ->
      # given an applicable rule for a target 
      service.resolve item1._id, item2._id, (err, results)->
        return done "Unable to resolve rules: #{err}" if err?

        # when executing this rule on that target
        service.execute results[item2._id][0].name, item1._id, item2._id, (err, result)->
          return done "Unable to execute rules: #{err}" if err?

          # then the rule is executed.
          assert.equal result, 'hello !'
          done()

    it 'should rule execution modifies item in database', (done) ->
      # given a rule that modified coordinates
      script = new Executable
        _id:'rule2', 
        content: """Rule = require '../model/Rule'
          class MoveRule extends Rule
            constructor: ->
              @name= 'rule 2'
            canExecute: (actor, target, callback) =>
              callback null, target.get('x').valueOf() is 1
            execute: (actor, target, callback) =>
              target.x++
              callback null, 'target moved'
          module.exports = new MoveRule()"""

      script.save (err) ->
        return done err if err?

        # given the rules that are applicable for a target 
        service.resolve item1._id, item2._id, (err, results)->
          return done "Unable to resolve rules: #{err}" if err?

          assert.equal 2, results[item2._id].length
          rule = rule for rule in results[item2._id] when rule.name is 'rule 2'
          assert.ok rule isnt null

          # when executing this rule on that target
          service.execute rule.name, item1._id, item2._id, (err, result)->
            if err?
              assert.fail "Unable to execute rules: #{err}"
              return done();

            # then the rule is executed.
            assert.equal result, 'target moved'
            # then the item was modified on database
            Item.find {x:2}, (err, items) =>
              return done "failed to retrieve items: #{err}" if err?
              assert.equal 1, items.length
              assert.equal 2, items[0].x
              done()

  describe 'given an item type and an item', ->

    beforeEach (done) ->
      ItemType.collection.drop ->
        Item.collection.drop ->
          # given a type
          return done err if err?
          type1 = new ItemType({name: 'dog'})
          type1.setProperty 'name', 'string', ''
          type1.setProperty 'fed', 'integer', 0
          type1.setProperty 'execution', 'string', ''
          type1.save (err, saved) ->
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
      script = new Executable
        _id:'rule6', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'
          ObjectId = require('mongodb').BSONPure.ObjectID

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 6'
            select: (callback) =>
              Item.find {type: new ObjectId "#{type1._id}"}, callback
            execute: (target, callback) =>
              target.set 'fed', target.get('fed')+1
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then the both dogs where fed
          Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            assert.equal 1, existing.get('fed'), 'lassie wasn\'t fed'
         
            Item.findOne {type: type1._id, name: 'medor'}, (err, existing) =>
              return done "Unable to find item: #{err}" if err?
              assert.equal 1, existing.get('fed'), 'medor wasn\'t fed'
              done()

    it 'should turn rule be executed in right order', (done) ->
      # given a first turn rule on lassie with rank 10
      script = new Executable
        _id:'rule7', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 7'
              @rank= 10
            select: (callback) =>
              Item.find {name: 'lassie'}, callback
            execute: (target, callback) =>
              target.set 'fed', 1
              target.set 'execution', target.get('execution')+','+@name
              callback null
          )()"""
      script.save (err) ->
        return done err if err?

        # given a another turn rule on lassie with rank 1
        script = new Executable
          _id:'rule8', 
          content: """TurnRule = require '../model/TurnRule'
            Item = require '../model/Item'

            module.exports = new (class Dumb extends TurnRule
              constructor: ->
                @name= 'rule 8'
                @rank= 1
              select: (callback) =>
                Item.find {name: 'lassie'}, callback
              execute: (target, callback) =>
                target.set 'fed', 10
                target.set 'execution', target.get('execution')+','+@name
                callback null
            )()"""
        script.save (err) ->
          return done err if err?

          # when executing a trurn
          service.triggerTurn (err)->
            return done "Unable to trigger turn: #{err}" if err?

            # then lassie fed status was reseted, and execution order is correct
            Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
              return done "Unable to find item: #{err}" if err?
              assert.equal ',rule 8,rule 7', existing.get('execution'), 'wrong execution order'
              assert.equal 1, existing.get('fed'), 'lassie was fed'
              done()

    it 'should disabled turn rule not be executed', (done) ->
      # given a disabled turn rule on lassie
      script = new Executable
        _id:'rule9', 
        content: """TurnRule = require '../model/TurnRule'
          Item = require '../model/Item'

          module.exports = new (class Dumb extends TurnRule
            constructor: ->
              @name= 'rule 9'
              @active = false
            select: (callback) =>
              Item.find {name: "#{item1.get('name')}"}, callback
            execute: (target, callback) =>
              target.set 'fed', -1
              callback null
          )()"""
      script.save (err) ->
        return done err if err?
        # when executing a trurn
        service.triggerTurn (err)->
          return done "Unable to trigger turn: #{err}" if err?

          # then lassie wasn't fed
          Item.findOne {type: type1._id, name: 'lassie'}, (err, existing) =>
            return done "Unable to find item: #{err}" if err?
            assert.equal 0, existing.get('fed'), 'disabled rule was executed'
            done()

    it 'should disabled rule not be resolved', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule10', 
        content: """Rule = require '../model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 10'
              @active = false
            canExecute: (actor, target, callback) =>
              callback null, true;
            execute: (actor, target, callback) =>
              target.set 'name', 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when resolving rule
        service.resolve item1._id, item1._id, (err, results) ->
          return done "Unable to resolve rules: #{err}" if err?
          # then the rule was not resolved
          assert.ok results[item1._id].length isnt 1, 'Disabled rule was resolved'
          done()

    it 'should disabled rule not be executed', (done) ->
      # Creates a dumb rule that always match
      script = new Executable 
        _id:'rule11', 
        content: """Rule = require '../model/Rule'
          
          module.exports = new (class Dumb extends Rule
            constructor: ->
              @name= 'rule 11'
              @active = false
            canExecute: (actor, target, callback) =>
              callback null, true;
            execute: (actor, target, callback) =>
              target.set 'name', 'changed !'
              callback null, 'hello !'
          )()"""
      script.save (err) ->
        # Creates a type
        return done err if err?
        # when executing rule
        service.execute 'rule 11', item1._id, item1._id, (err, results) ->
          # then the rule was not resolved
          assert.ok err?.indexOf('does not apply') isnt -1, 'Disabled rule was executed'
          done()

    it 'should not turn rule be exportable to client', (done) ->
      # when exporting rules to client
      service.export (err, rules) ->
        return done "Unable to export rules: #{err}" if err?
        for key of rules
          assert.fail 'no rules may have been returned'
        done()