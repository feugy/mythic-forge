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
createPath = (folderPath, name) ->
  if not path.existsSync folderPath
    try 
      fs.mkdirSync folderPath
      logger.info "Executable name folder '#{folderPath}' successfully created"
    catch err
      throw "Unable to create the Executable #{name} folder '#{folderPath}': #{err}"
createPath root
createPath compiledRoot

# Executable are Javascript executable script, defined at runtime and serialized on the file-system
class Executable

  # Find all existing executables.
  #
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Array<Executable>] list (may be empty) of executables
  @find: (callback) ->
    fs.readdir root, (err, files) ->
      return callback "Error while listing executables: #{err}" if err?
      
      executables = []
      
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
          executables.push executable
          end()

      # each individual file must be read
      async.forEach files, readFile, (err) -> callback(null, executables)

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
      # Now, compile it to js
      try 
        js = coffee.compile @content
      catch err2
        return callback "Error while compilling executable #{@_id}: #{err2}"
      # Eventually, write a copy with a js extension
      fs.writeFile @compiledPath, js, (err3) =>
        return callback "Error while saving compiled executable #{@_id}: #{err3}" if err3?
        logger.debug "executable #{@_id} successfully compiled"
        callback null, this

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
        fs.unlink @compiledPath, (err2) =>
          return callback "Error while removing compiled executable #{@_id}: #{err2}" if err2?
          logger.debug "executable #{@_id} successfully removed"
          callback null, this

module.exports = Executable