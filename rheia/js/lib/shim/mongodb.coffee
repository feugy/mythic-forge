# Mongo dependency shim
define [], ->
  {
    BSONPure: 

      # Shim for ObjectID
      ObjectID: class ObjectID
        val: null # String value of this object
        constructor: (@val) -> null # nothing to do
        toString: => @val
  }