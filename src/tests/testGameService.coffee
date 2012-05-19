Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'
service = require('../main/service/GameService').get()
     
type = null
item1 = null
item2 = null
item3 = null

module.exports = 

  setUp: (end) ->
    # cleans ItemTypes and Items
    ItemType.collection.drop -> Item.collection.drop -> 
      # given an item type
      type = new ItemType {name: 'character'}
      type.setProperty 'name', 'string', ''
      type.setProperty 'health', 'integer', 10
      type.save (err, saved) ->
        throw new Error err if err?
        type = saved
        new Item({type: type, name: 'Jack', x:0, y:0}).save (err, saved) ->
          throw new Error err if err?
          item1 = saved
          new Item({type: type, name: 'John', x:10, y:10}).save (err, saved) ->
            throw new Error err if err?
            item2 = saved
            new Item({type: type, name: 'Peter'}).save (err, saved) ->
              throw new Error err if err?
              item3 = saved
              end()

  'should consultMap returned only relevant items': (test) ->
    # when retrieving items within coordinate -5:-5 and 5:5
    service.consultMap -5, -5, 5, 5, (err, items) ->
      # then only item1 is returned
      test.equal 1, items.length
      test.ok item1.equals items[0]
      test.done()
        
  'should consultMap returned nothing if no item found': (test) ->
    # when retrieving items within coordinate -1:-1 and -5:-5
    service.consultMap -1, -1, -5, -5, (err, items) ->
      # then no items returned
      test.equal 0, items.length
      test.done()
