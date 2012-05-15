fs = require 'fs'
p = require 'path'
async = require 'async'

module.exports =

  # Remove everything inside the specified folder, but does not removes the folder itself.
  # Do not recurse inside sub-folders
  #
  # @param path [String] full path to rhe concerned folder
  # @param  callback [Function] end callback, executed with one parameter:
  #   @param err [String] error message. Null if no error occured.
  cleanFolder: (path, callback) ->
    fs.readdir path, (err, files) ->
      if files?
        removeFile = (file, callback) -> 
          fs.unlink(p.join(path, file), (err)-> callback(err))
        async.forEach files, removeFile, (err) -> callback(err)