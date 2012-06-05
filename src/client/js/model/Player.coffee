define [
  'backbone'
  'model/Item'
], (Backbone, Item) ->

  # Player account.
  class Player extends Backbone.Model

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player account login.
    login: null

    # The associated character. Null if no character associated yet.
    character: null

    # Playr constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 
      # Construct an Item for the corresponding character
      if attributes?.character?
        @set 'character', new Item attributes.character


    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current field is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Player