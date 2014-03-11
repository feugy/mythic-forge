###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

_ = require 'underscore'
pathUtils = require 'path'
coffee = require 'coffee-script'
stylus = require 'stylus'
fs = require 'fs-extra'
async = require 'async'
requirejs = require 'requirejs'
utils = require '../util/common'
versionUtils = require '../util/versionning'
logger = require('../util/logger').getLogger 'service'
notifier = require('../service/Notifier').get()

repo = null
root = null

# Singleton instance
_instance = undefined
module.exports = class DeployementService

  @get: ->
    _instance ?= new _DeployementService()

# The AuthoringService export feature relative to game client.
#
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _DeployementService

  # **private**
  # Version currently deployed.
  # Only one version may be deployed at a time.
  @_deployed: null

  # **private**
  # Flag to avoid commit/rollback during unfinished deploy
  @_deployPending: false

  # **private**
  # Email of the player that triggers deployement.
  @_deployer: null

  # Service constructor. Invoke init()
  # Triggers 'initialized' event on singleton instance when ready.
  constructor: ->
    @_deployed = null
    @init (err) =>
      throw new Error "Failed to init: #{err}" if err?

  # Initialize folders and git repository.
  # 
  # @param callback [Function] initialization end callback.
  # @option callback err [Sting] error message. Null if no error occured.
  init: (callback) =>
    versionUtils.initGameRepo logger, (err, _root, _repo) =>
      return callback err if err?
      root = _root
      repo = _repo
      callback null

  # Simple getter to known if a deployement is pending.
  # @return the version name of a deployement that has been triggered and not yet committed or rollbacked.
  # Null otherwise.
  deployedVersion: =>
    if @_deployed? then "#{@_deployed}" else null

  # Performs compilation and optimization of game client, and send 'deployment' notifications
  # with relevant step name and number: 
  # 1 - makes a copy to temporary folder (DEPLOY_START)
  # 2 - compiles stylus stylesheets and remove sources (COMPILE_STYLUS)
  # 3 - compiles coffee files and removes sources (COMPILE_COFFEE)
  # 4 - optimize with requirejs utilities (OPTIMIZE_JS)
  # 5 - make html static resources cacheable (OPTIMIZE_HTML)
  # 6 - save current production folder into save folder (DEPLOY_FILES)
  # 7 - move optimization results into production (DEPLOY_END)
  #
  # Then the deployement is stopped and must be finished with `commit()` or `rollback()`
  #
  # @param version [String] name of the deployed version. Null to disabled version checking
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] invoked when deployement is done, with following parameters:
  # @option callback err [String] an error message, or null if no error occures
  # @option callback path [String] path to the compiled and optimized location of the client
  deploy: (version, email, callback) =>
    return callback "Deployment of version #{@_deployed} already in progress" if @_deployed?
    return callback "Commit or rollback of previous version not finished" if @_deployPending

    # check version unicity
    listVersions (err, versions) =>
      return callback err if err?
      return callback "Version #{version} already used" if version in versions

      @_deployPending = true
      @_deployed = "#{version}"
      @_deployer = email

      error = (err) =>
        notifier.notify 'deployement', 'DEPLOY_FAILED', err
        @_deployed = null
        @_deployer = null
        @_deployPending = false
        callback err

      # first, clean to optimized destination
      folder = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.optimized'
      production = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.production'
      save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.save'

      notifier.notify 'deployement', 'DEPLOY_START', 1, @_deployed, @_deployer

      fs.remove folder, (err) => fs.remove "#{folder}.out", (err) =>
        return error "Failed to clean optimized folder: #{err}" if err?
        fs.mkdirs folder, (err) =>
          return error "Failed to create optimized folder: #{err}" if eff?
          logger.debug "optimized folder #{folder} cleaned"

          # second, move sources to optimized destination
          fs.copy root, folder, (err) =>
            return error "Failed to copy to optimized folder: #{err}" if err?
            logger.debug "client copied to optimized folder"

            # fifth, optimize with requirejs
            _optimize = =>
              notifier.notify 'deployement', 'OPTIMIZE_JS', 4
              optimize folder, (err, root, temp) =>
                return error "Failed to optimized client: #{err}" if err?
                # sixth, make it cacheable
                notifier.notify 'deployement', 'OPTIMIZE_HTML', 5
                makeCacheable temp, root, @_deployed, (err, result) =>
                  return error "Failed to make client cacheable: #{err}" if err?
                  # save production folder content and move everything in it
                  notifier.notify 'deployement', 'DEPLOY_FILES', 6
                  fs.remove save, (err) =>
                    return error "Failed to clean save folder: #{err}" if err? and err.code isnt 'ENOENT'
                    fs.mkdir save, (err) =>
                      return error "Failed to create save folder: #{err}" if err?
                      fs.copy production, save, (err) =>
                        return error "Failed to save current production: #{err}" if err? and err.code isnt 'ENOENT' # when production do not exists
                        logger.debug "old version saved"
                        fs.remove production, (err) =>
                          return error "Failed to clean production folder: #{err}" if err? and err.code isnt 'ENOENT'
                          fs.copy result, production, (err) =>
                            return error "Failed to copy into production folder: #{err}" if err?
                            logger.debug "client moved to production folder"

                            # cleans optimization folders
                            async.forEach [folder, temp, result], fs.remove, (err) =>
                              notifier.notify 'deployement', 'DEPLOY_END', 7
                              @_deployPending = false
                              # ignore removal errors
                              callback null

            # fourth, compile coffee scripts
            _compileCoffee = =>
              notifier.notify 'deployement', 'COMPILE_COFFEE', 3
              utils.find folder, /^.*\.coffee?$/, (err, results) =>
                return _optimize() if err? or results.length is 0
                async.forEach results, (script, next) =>
                  compileCoffee script, next
                , (err) =>
                  return error "Failed to compile coffee scripts: #{err}" if err?
                  _optimize()

            # third, compile stylus sheets
            notifier.notify 'deployement', 'COMPILE_STYLUS', 2
            utils.find folder, /^.*\.styl(us)?$/, (err, results) =>
              return _compileCoffee() if err? or results.length is 0
              async.forEach results, (sheet, next) =>
                compileStylus sheet, next
              , (err) =>
                return error "Failed to compile stylus sheets: #{err}" if err?
                _compileCoffee()

  # Commit definitively the current deployement, and send 'deployment' notifications
  # with relevant step name and number: 
  # 1 - creates a version named after version used in `deploy` (COMMIT_START)
  # 2 - removes the previous game save (COMMIT_END)
  #
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] invoked when deployement is committed, with following parameters:
  # @option callback err [String] an error message, or null if no error occures
  commit: (email, callback) =>
    return callback 'Commit can only be performed after deploy' unless @_deployed?
    return callback "Commit can only be performed be deployement author #{@_deployer}" unless @_deployer is email
    return callback 'Deploy not finished' if @_deployPending
    @_deployPending = true

    error = (err) =>
      notifier.notify 'deployement', 'COMMIT_FAILED', err
      callback err

    save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.save'

    notifier.notify 'deployement', 'COMMIT_START', 1
    
    # first create tag
    @createVersion @_deployed, @_deployer, 2, (err) =>
      return error "Failed to create version: #{err}" if err?

      # at least, remove save folder
      fs.remove save, (err) =>
        return error "Failed to remove previous version save: #{err}" if err? and err.code isnt 'ENOENT'
        logger.debug "previous game client files deleted"

        # end of the deployement
        @_deployed = null
        @_deployer = null
        @_deployPending = false
        notifier.notify 'deployement', 'COMMIT_END', 3
        callback null

  # Rollback the current deployement, and send 'deployment' notifications
  # with relevant step name and number: 
  # 1 - remove current deployed game client (ROLLBACK_START)
  # 2 - restore previous game client (ROLLBACK_END)
  #
  # @param email [String] the author email, that must be an existing player email
  # @param callback [Function] invoked when deployement is rollbacked, with following parameters:
  # @option callback err [String] an error message, or null if no error occures
  rollback: (email, callback) =>
    return callback 'Rollback can only be performed after deploy' unless @_deployed?
    return callback "Rollback can only be performed be deployement author #{@_deployer}" unless @_deployer is email
    return callback 'Deploy not finished' if @_deployPending
    @_deployPending = true

    save = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.save'
    production = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.production'

    error = (err) =>
      notifier.notify 'deployement', 'ROLLBACK_FAILED', err
      callback err
    
    notifier.notify 'deployement', 'ROLLBACK_START', 1

    # removes production folder
    fs.remove production, (err) =>
      return error "Failed to remove deployed version: #{err}" if err? and err.code isnt 'ENOENT'
      logger.debug "deployed game client files deleted"

      fs.rename save, production, (err) =>
        return error "Failed to move saved version to production: #{err}" if err?
        logger.debug "previous game client files restored"

        # end of the deployement
        @_deployed = null
        @_deployer = null
        @_deployPending = false
        notifier.notify 'deployement', 'ROLLBACK_END', 2
        callback null

  # List current developpement version and deployement state
  #
  # @param callback [Function] invoked with versions:
  # @option callback err [String] an error message, or null if no error occures
  # @option callback state [Object] server state, with:
  # @option callback state current [String] current version, or null if no version 
  # @option callback state versions [Array<String>] list of known version
  # @option callback state deployed [String] name of the deployed version, null if no pending deployement 
  # @option callback state author [String] email of the deployer, null if no pending deployement
  # @option callback state inProgress [Boolean] true if deployement still in progress
  deployementState: (callback) =>
    # get known tags
    versionUtils.quickTags repo, (err, tags) =>
      return callback "Failed to consult versions: #{err}" if err?
      tags.reverse() # make the last tag comming first
      tagIds = _.pluck tags, 'id'
     
      # get history
      versionUtils.quickHistory repo, (err, history) =>
        return callback "Failed to consult history: #{err}" if err?

        result = 
          deployed: @_deployed
          inProgress: @_deployPending
          author: @_deployer
          current: null
          versions: _.pluck tags, 'name'

        # parse commits from the last one
        for commit in history
          # confront the commit id and the tag commits
          for id, i in tagIds when id is commit.id
            # we found our parent !
            result.current = tags[i].name
            return callback null, result

        callback null, result

  # Creates a given version of the game client, its corresponding rules and images.
  # 
  # @param version [String] the desired version
  # @param email [String] the author email, that must be an existing player email
  # @param notifNumber [Integer] notification number, default to 1
  # @param callback [Function] invoked when version is created
  # @option callback err [String] an error message, or null if no error occures
  createVersion: (version, email, notifNumber, callback) =>
    # default values
    if _.isFunction notifNumber
      callback = notifNumber
      notifNumber = 1
    return callback 'Spaces not allowed in version names' unless -1 is version.indexOf ' '
    # get tags first
    listVersions (err, versions) =>
      return callback err if err?
      # check that we know version
      return callback "Cannot reuse existing version #{version}" if version in versions

      require('./PlayerService').get().getByEmail email, (err, author) =>
        return callback "Failed to get author: #{err}" if err?
        return callback "No author with email #{email}" unless author?
        
        dev = pathUtils.resolve pathUtils.normalize utils.confKey 'game.client.dev'
        rules = pathUtils.resolve pathUtils.normalize utils.confKey 'game.executable.source'
        images = pathUtils.resolve pathUtils.normalize utils.confKey 'game.image'
        # add game files and executables
        repo.add [dev, rules, images], {'ignore-errors': true, A:true}, (err) ->
          return callback "Failed to add files to version: #{err}" if err?
          # TODO use version message
          repo.commit version, {author: versionUtils.getAuthor author}, (err, stdout) =>
            # ignore commit warning, for example about line endings
            err = null if err?.code is 1 and -1 isnt "#{err}".indexOf 'warning:'
            return callback "Failed to commit: #{utils.purgeFolder err, root} #{utils.purgeFolder stdout, root}" if err?
            
            # and at last ceates the tag
            repo.create_tag version, (err) ->
              return callback "Failed to create version: #{err}" if err?
              notifier.notify 'deployement', 'VERSION_CREATED', notifNumber, version

              callback null

  # Restore a given version of the game client.
  # All modification made between the previous version and now will be lost.
  # 
  # @param version [String] the desired version
  # @param callback [Function] invoked when game client was restored
  # @option callback err [String] an error message, or null if no error occures
  restoreVersion: (version, callback) =>
    return callback "Deployment of version #{@_deployed} in progress" if @_deployed?

    # get tags first
    listVersions (err, versions) =>
      return callback err if err?
      # check that we know version
      return callback "Unknown version #{version}" unless version in versions

      logger.debug "reset working copy to version #{version}"
      # now we can rest with no fear...
      repo.git 'reset', hard:true, [version], (err, stdout, stderr) =>
        return callback "Failed to restore version #{version}: #{err}" if err?
        notifier.notify 'deployement', 'VERSION_RESTORED', 1, version

        callback null

# Retrieve the list of versions names    
# 
# @param callback [Function] invoked when versions retrieved, with arguments:
# @option callback err [String] an error string, or null if no error occured
# @option callback versions [Array<String>] an array of versions names (may be empty)
listVersions = (callback) ->
  versionUtils.quickTags repo, (err, tags) ->
    return callback "Failed to list existing versions: #{err}" if err?
    callback null, _.pluck tags, 'name'

# Tries to compile stylus sheet, and to creates its compiled css equivalent.
# Source file is removed
#
# @param sheet [String] path to compiled stylus file
# @param callback [Function] compilation end function, invoked with
# @option callback err [String] an error details string, or null if no error occured
compileStylus = (sheet, callback) ->
  # compute destination name
  parent = pathUtils.dirname sheet
  name = pathUtils.basename sheet
  destination = pathUtils.join parent, name.replace /\.styl(us)?$/i, '.css'
  logger.debug "compiles stylus sheet #{sheet} with parent #{parent}"
  # read the sheet
  fs.readFile sheet, (err, content) =>
    return callback "failed to read content for #{sheet}: #{err}" if err?
    # try to compile it (allow to include from the same folder)
    stylus(content.toString()).set('compress'; 'true').set('paths', [parent]).render (err, css) ->
      return callback "#{sheet}: #{err}" if err?
      # writes destination file
      fs.writeFile destination, css, (err) =>
        return callback "failed to write #{destination}: #{err}" if err?
        # at last, removes the original
        fs.remove sheet, (err) =>
          return callback "failed to delete #{sheet}: #{err}" if err?
          callback null

# Tries to compile coffee script, and to creates its compiled js equivalent.
# Source file is removed
#
# @param script [String] path to compiled coffee script
# @param callback [Function] compilation end function, invoked with
# @option callback err [String] an error details string, or null if no error occured
compileCoffee = (script, callback) ->
  # compute destination name
  destination = script.replace /\.coffee?$/i, '.js'
  logger.debug "compiles coffee script #{script}"
  # read the script
  fs.readFile script, (err, content) =>
    return callback "failed to read content for #{script}: #{err}" if err?
    try 
      js = coffee.compile content.toString(), bare: false
      # writes destination file
      fs.writeFile destination, js, (err) =>
        return callback "failed to write #{destination}: #{err}" if err?
        # at last, removes the original
        fs.remove script, (err) =>
          return callback "failed to delete #{script}: #{err}" if err?
          callback null
    catch exc
      callback "#{script}: #{exc}"

# Identify requirejs main file and configuration file, and optimize the game client.
# Main file is included from an HTML file with '<script data-main'
# Configuration file is a Javascript file containing a call to 'requirejs.config('
#
# @param folder [String] the folder containing the optimized game client
# @param callback [Function] optimization end function, invoked with
# @option callback err [String] an error details string, or null if no error occured.
# @option callback root [String] absolute path of the main HTML file.
# @option callback out [String] absolute path of folder containing optimized results
optimize = (folder, callback) ->
  folderOut = "#{folder}.out"

  # search main entry point
  requireMatcher = /<script[^>]*data-main\s*=\s*(["'])(.*)(?=\1)/i

  utils.find folder, /^.*\.html$/i, requireMatcher, (err, results) ->
    return callback "failed to identify html page including requirejs: #{err}" if err?
    return callback 'no html page including requirejs found' if results.length is 0
    # choose the least path length
    main = _.min results, (path) -> path.length

    # read content to get the data-main path
    fs.readFile main, (err, content) ->
      extract = content.toString().match requireMatcher
      mainFile = extract?[2]

      # it's possible that we took too large because of the regexp lookahead
      idx = mainFile.indexOf '"'
      idx = mainFile.indexOf "'" if idx is -1
      mainFile = mainFile.slice 0, idx unless idx is -1

      idx = mainFile.lastIndexOf '/'
      if idx isnt -1
        mainFile = mainFile.substring idx+1
        baseUrl = './'+extract?[2].substring 0, idx
      else 
        baseUrl = './'

      logger.debug "found main requirejs file #{mainFile} in base url #{baseUrl}"

      # search file containing requirejs config
      utils.find folder, /^.*\.js$/, /requirejs\.config/i, (err, results) ->
        return callback "failed to identify requirejs configuration file: #{err}" if err?
        return callback 'no requirejs configuration file found' if results.length is 0
        # choose the least path length
        configFile = _.min results, (path) -> path.length

        logger.debug "use requirejs configuration file #{configFile}"

        config =
          appDir: folder
          dir: folderOut
          baseUrl: baseUrl
          mainConfigFile: configFile
          optimizeCss: 'standard'
          preserveLicenseComments: false
          locale: null
          optimize: 'uglify2'
          useStrict: true
          modules: [
            name: mainFile
          ]

        # at least, performs optimization
        start = new Date().getTime()
        logger.debug "start optimization..."
        requirejs.optimize config, (result) ->
          return callback result.message if utils.isA result, Error
          logger.debug "optimization succeeded in #{(new Date().getTime() - start)/1000}s"
          logger.debug result
          callback null, main, folderOut
        , (err) ->
          callback err.message

# Moves game files from optimized folder to production folder.
# Creates a folder for static assets (every files) named with current timestamp, 
# and only keeps the main HTML file at root. 
# Changes its relative path (either '<script>' and '<link>') to aim at new content
#
# @param folder [String] the folder containing the optimized game client
# @param main [String] Absolute path of the main HTML file
# @param version [String] Name of the deployed version
# @param callback [Function] optimization end function, invoked with
# @option callback err [String] an error details string, or null if no error occured.
# @option callback out [String] absolute path of folder containing optimized results
makeCacheable = (folder, main, version, callback) ->
  # first cleans and creates a temporary destination folder
  dest = "#{folder}.tmp"
  fs.remove dest, (err) ->
    return callback "failed to clean temporary folder: #{err}" if err?

    # then copies all optimized content inside a timestamped folder
    timestamp = "#{new Date().getTime()}"
    timestamped = pathUtils.join dest, timestamp
    fs.mkdirs timestamped, (err) ->
      return callback "failed to create timestamped folder: #{err}" if err?

      logger.debug "copy inside #{timestamped}"
      fs.copy folder, timestamped, (err) ->
        return callback "failed to copy to timestamped folder: #{err}" if err?
        
        # removes main file and build.txt
        async.forEach ['build.txt', pathUtils.basename main], (file, next) ->
          fs.remove pathUtils.join(timestamped, file), next
        , (err) ->
          return callback "failed to remove none-cached files: #{err}" if err?

          # copies main file next to timestamped folder
          newMain = pathUtils.join dest, pathUtils.basename main
          logger.debug "copy main file #{newMain}"
          fs.copy main, newMain, (err) ->
            return callback "failed to copy new main file: #{err}" if err?

            # replaces links from main html file
            fs.readFile newMain, (err, content) ->
              return callback "failed to read new main file: #{err}" if err?
              content = content.toString()
              
              logger.debug "replace links inside #{newMain}"
              # <script data-main="" src="" />
              specs = [
                pattern: /<\s*script([^>]*)data-main\s*=\s*(["'])(.*(?=\2))\2([^>]*)src\s*=\s*(["'])(.*(?=\5))\5/gi
                replace: "<script$1data-main=\"#{timestamp}/$3\"$4src=\"#{timestamp}/$6\""
              ,
                pattern: /<\s*script([^>]*)src\s*=\s*(["'])(.*(?=\2))\2([^>]*)data-main\s*=\s*(["'])(.*(?=\5))\5/gi
                replace: "<script$1src=\"#{timestamp}/$3\"$4data-main=\"#{timestamp}/$6\""
              ,
                pattern: /<\s*link([^>]*)href\s*=\s*(["'])(.*(?=\2))\2/gi
                replace: "<link$1href=\"#{timestamp}/$3\""
              ,
                pattern: /\{\{version\}\}/g
                replace: version
              ]
              content = content.replace spec.pattern, spec.replace for spec in specs
              fs.writeFile newMain, content, (err) ->
                return callback "failed to write new main file: #{err}" if err?
                logger.debug "#{newMain} rewritten"
                callback null, dest