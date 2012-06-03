Player = require '../main/model/Player'
Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
watcher = require('../main/model/ModelWatcher').get()


player = null
item = null
type = null

module.exports = 
  setUp: (end) ->
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
            end()
      
  tearDown: (end) ->
    Player.collection.drop -> ItemType.collection.drop -> Item.collection.drop -> end()

  'should player be created': (test) -> 
    # given a new Player
    player = new Player {login:'Joe', characterId:item._id}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      test.equal 'Player', className
      test.equal 'creation', operation
      test.ok player.equals instance

    # when saving it
    player.save (err) ->
      throw new Error "Can't save player: #{err}" if err?

      # then it is in mongo
      Player.find {}, (err, docs) ->
        throw new Error "Can't find player: #{err}" if err?
        # then it's the only one document
        test.equal docs.length, 1
        # then it's values were saved
        test.equal 'Joe', docs[0].get 'login'
        test.equal item._id.toString(), docs[0].get('characterId').toString()
        test.expect 6
        test.done()

  'given a Player': 
    setUp: (end) ->
      player = new Player {login:'Jack', characterId:item._id}
      player.save -> end()

    'should player be removed': (test) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        test.equal 'Player', className
        test.equal 'deletion', operation
        test.ok player.equals instance

      # when removing a player
      player.remove ->

        # then it's not in mongo anymore
        Player.find {}, (err, docs) ->
          throw new Error "Can't find player: #{err}" if err?
          test.equal docs.length, 0
          test.expect 4
          test.done()

    'should player be updated': (test) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        test.equal 'Player', className
        test.equal 'update', operation
        test.ok player.equals instance
        test.ok null is instance.characterId

      # when modifying and saving a player
      player.set 'characterId', null
      player.save ->

        Player.find {}, (err, docs) ->
          throw new Error "Can't find player: #{err}" if err?
          # then it's the only one document
          test.equal docs.length, 1
          # then only the relevant values were modified
          test.equal 'Jack', docs[0].get 'login'
          test.ok null is docs[0].get 'characterId'
          test.expect 7
          test.done()