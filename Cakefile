# Cakefile used to provide a portable build and test system.
# The only requirement is to have Coffee-script globally installed, 
# and to have retrieved the npm dependencies with `npm install`
#
# Available tasks: 
# * build - compiles coffee-script from hyperion/src to hyperion/lib 
# * test - runs all tests with mocha (configuration in test/mocha.opts)
# * clean - removed hyperion/lib folder
fs = require 'fs'
_ = require 'underscore'
async = require 'async'
{join} = require 'path'
{spawn} = require 'child_process'

isWin = process.platform.match(/^win/)?

task 'build', 'compile Hyperion\'s coffee-script source files', -> 
  _launch 'coffee', ['-c', '-b', '-o', join('hyperion', 'lib'), join('hyperion', 'src')], {}, ->
    _remove '-p' if isWin


task 'test', 'run tests with mocha', -> 
  _launch 'mocha', [], {NODE_ENV: 'test'}, -> 
    # test success, clean test folder
    _remove join '..', 'tmp'

task 'clean', 'removes hyperion/lib folder', -> 
  _remove join('hyperion', 'lib'), (err) -> 
    console.error err if err?
    process.exit if err? then 1 else 0

_launch = (cmd, options=[], env={}, callback) ->
  # look into node_modules to find the command
  cmd = "#{cmd}.cmd" if isWin
  cmd = join 'node_modules', '.bin', cmd
  # spawn it now, useing modified environement variables and caller process's standard input/output/error
  app = spawn cmd, options, stdio: 'inherit', env: _.extend({}, process.env, env)
  # invoke optionnal callback if command succeed
  app.on 'exit', (code) -> 
    return callback() if code is 0 and callback?
    process.exit code

# rimraf's remove (used in fs-extra) have many problems on windows: provide a custom naive implementation.
#
# @param path removed file of folder
# @param callback [Function] end callback, executed with one parameter:
# @option callback err [String] error message. Null if no error occured.
_remove = (path, callback) ->
  callback ||= -> 
  fs.stat path, (err, stats) ->
    _processOp path, err, (err) ->
      return callback() unless stats?
      return callback err if err?
      # a file: unlink it
      if stats.isFile()
        return fs.unlink path, (err) -> _processOp path, err, callback
      # a folder, recurse with async
      fs.readdir path, (err, contents) ->
        return callback new Error "failed to remove #{path}: #{err}" if err?
        async.forEach (join path, content for content in contents), _remove, (err) ->
          return callback err if err?
          # remove folder once empty
          fs.rmdir path, (err) -> _processOp path, err, callback

# files/folders common behaviour: handle different error codes and retry if possible
#
# @param path [String] removed folder or file
# @param err [Object] underlying error, or null if removal succeeded
# @param callback [Function] processing end callback, invoked with arguments
# @option callback err [Object] an error object, or null if removal succeeded
_processOp = (path, err, callback) ->
  unless err?
    return callback null 
  switch err.code 
    when 'EPERM'
      # removal not allowed: try to change permissions
      fs.chmod path, '755', (err) ->
        return callback new Error "failed to change #{path} permission before removal: #{err}" if err?
        _remove path, callback
    when 'ENOTEMPTY', 'EBUSY'
      # not empty folder: just let some time to OS to really perform deletion
      _.defer ->
        _remove path, callback
      , 50
    when 'ENOENT'
      # no file/folder: it's a success :)
      callback null
    else
      callback new Error "failed to remove #{path}: #{err}"
