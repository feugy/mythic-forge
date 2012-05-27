fs = require 'fs'
path = require 'path'
async = require 'async'
coffee = require 'coffee-script'
logger = require('../logger').getLogger 'model'
utils = require '../utils'

root = utils.confKey 'executable.source'
compiledRoot = utils.confKey 'executable.target'
encoding = utils.confKey 'executable.encoding', 'utf8'
ext = utils.confKey 'executable.extension','.coffee'

# Enforce the folder existence.
# This function IS intended to be synchonous, because the folder needs to exists before exporting the class.
#
# @param folderPath [String] path to the checked folder
# @param forceRemove [boolean] if specifed and true, first erase the folder.
createPath = (folderPath, forceRemove) ->
  # force Removal if specified
  if forceRemove
    files = fs.readdirSync folderPath
    fs.unlinkSync path.join folderPath, file for file in files
    fs.rmdirSync folderPath 

  if not path.existsSync folderPath
    try 
      fs.mkdirSync folderPath
      logger.info "Executable folder '#{folderPath}' successfully created"
    catch err
      throw "Unable to create the Executable #{name} folder '#{folderPath}': #{err}"

createPath root

# Do a single compilation of a source file.
#
# @param executable [Executable] the executable to compile
# @param callback [Function] end callback, invoked when the compilation is done with the following parameters
# @option callback err [String] an error message. Null if no error occured
# @option callback executable [Executable] the compiled executable
compileFile = (executable, callback) ->
  try 
    js = coffee.compile executable.content
  catch exc
    return callback "Error while compilling executable #{executable._id}: #{exc}"
  # Eventually, write a copy with a js extension
  fs.writeFile executable.compiledPath, js, (err) =>
    return callback "Error while saving compiled executable #{executable._id}: #{err}" if err?
    logger.debug "executable #{executable._id} successfully compiled"
    # store it in local cache.
    executables[executable._id] = executable
    callback null, executable

# local cache of executables
executables = {}

# Executable are Javascript executable script, defined at runtime and serialized on the file-system
class Executable

  # Reset the executable local cache. It recompiles all existing executables
  #
  # @param callback [Function] invoked when the reset is done.
  # @option callback err [String] an error callback. Null if no error occured.
  @resetAll: (callback) ->
    # clean local files, and compiled scripts
    executables = {}
    createPath compiledRoot, true

    fs.readdir root, (err, files) ->
      return callback "Error while listing executables: #{err}" if err?

      readFile = (file, end) -> 
        # only take coffeescript in account
        if ext isnt path.extname file
          return end()
        # creates an empty executable
        executable = new Executable file.replace ext, ''

        fs.readFile executable.path, encoding, (err, content) ->
          return callback "Error while reading executable '#{executable._id}': #{err}" if err?
          # complete the executable content, and add it to the array.
          executable.content = content
          compileFile executable, (err, executable) ->
            return callback "Compilation failed: #{err}" if err?
            end()

      # each individual file must be read
      async.forEach files, readFile, (err) -> 
        logger.debug 'Local executables cached successfully reseted' unless err?
        callback err

  # Find all existing executables.
  #
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Array<Executable>] list (may be empty) of executables
  @find: (callback) ->
    # just take the local cache and transforms it into an array.
    array = []
    array.push executable for _id, executable of executables
    callback null, array

  # The unic file name of the executable, which is also its id.
  _id: null

  # The executable content (Utf-8 string encoded).
  content: ''

  # Absolute path to the executable source.
  path: ''

  # Absolute aath to the executable compiled script
  compiledPath: ''

  # Create a new executable, with its file name.
  # 
  # @param _id [String] its file name (without it's path).
  # @param content [String] the file content. Empty by default.
  constructor: (@_id, @content = '') ->
    @path = path.join root, @_id+ext
    @compiledPath = path.join compiledRoot, @_id+'.js'

  # Save (or update) a executable and its content.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  save: (callback) =>
    fs.writeFile @path, @content, encoding, (err) =>
      return callback "Error while saving executable #{@_id}: #{err}" if err?
      logger.debug "executable #{@_id} successfully saved"
      # Trigger the compilation.
      compileFile this, callback

  # Remove an existing executable.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  remove: (callback) =>
    path.exists @path, (exists) =>
      return callback "Error while removing executable #{@_id}: this executable does not exists" if not exists
      fs.unlink @path, (err) =>
        return callback "Error while removing executable #{@_id}: #{err}" if err?
        fs.unlink @compiledPath, (err) =>
          return callback "Error while removing compiled executable #{@_id}: #{err}" if err?
          logger.debug "executable #{@_id} successfully removed"
          delete executables[@_id]
          callback null, this

module.exports = Executable