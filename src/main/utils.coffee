yaml = require 'js-yaml'
fs = require 'fs'
pathUtil = require 'path'

classToType = {}
for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
  classToType["[object " + name + "]"] = name.toLowerCase()

conf = null

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

  # Read a configuration key inside the YAML configuration file (utf-8 encoded).
  # At first call, performs a synchronous disk access, because configuraiton is very likely to be read
  # before any other operation. The configuration is then cached.
  # 
  # The configuration file read is named 'xxx-conf.yaml', where xxx is the value of NODE_ENV (dev if not defined) 
  # and located in a "conf" folder under the execution root.
  #
  # @param key [String] the path to the requested key, splited with dots.
  # @param def [Object] the default value, used if key not present. 
  # If undefined, and if the key is missing, an error is thrown.
  # @return the expected key.
  confKey: (key, def) ->
    if conf is null
      confPath = pathUtil.resolve "./conf/#{if process.env.NODE_ENV then process.env.NODE_ENV else 'dev'}-conf.yml"
      try 
        conf = yaml.load fs.readFileSync confPath, 'utf8'
      catch err
        throw new Error "Cannot read or parse configuration file '#{confPath}': #{err}"
    
    path = key.split '.'
    obj =  conf
    last = path.length-1
    for step, i in path
      unless step of obj
        # missing key or step
        throw new Error "The #{key} key is not defined in the configuration file" if def is undefined
        return def
      unless i is last
        # goes deeper
        obj = obj[step]
      else 
        # last step: returns value
        return obj[step]
