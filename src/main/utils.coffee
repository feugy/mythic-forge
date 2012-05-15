
classToType = {}
for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
  classToType["[object " + name + "]"] = name.toLowerCase()

module.exports =
  # This method is intended to replace the broken typeof() Javascript operator.
  #
  # @param obj [Object] any check object
  # @return the string representation of the object type. One of the following:
  # object, boolean, number, string, function, array, date, regexp, undefined, null
  #
  # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
  type: (obj) ->
    strType = Object::toString.call(obj)
    classToType[strType] or "object"

  # isA() is an utility method that check if an object belongs to a certain class, or to one 
  # of it's subclasses. Uses the classes names to performs the test.
  #
  # @param obj [Object] the object which is tested
  # @param clazz [Class] the class against which the object is tested
  # @return true if this object is a the specified class, or one of its subclasses. false otherwise
  isA: (obj, clazz) ->
    return false if not (obj? and clazz?)
    currentClass = obj.constructor
    while currentClass?
      return true  if currentClass.name == clazz.name
      currentClass = currentClass.__super__?.constructor
    false