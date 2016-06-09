# Mongo dependency shim
define [], ->
  {
    # Shim for ObjectID
    ObjectID: class ObjectID
      val: null # String value of this object
      constructor: (@val) -> null # nothing to do
      toString: => @val
  }