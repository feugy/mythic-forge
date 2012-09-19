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

define [
  'backbone'
  'model/sockets'
], (Backbone, sockets) ->

  # The administration service is wired to server features not related to a model.
  # For example, it triggers game client deployement
  # Extends Backbone.Events to trigger events: each method will publish an event (same name as method)
  # when finished.
  # The following methods are available:
  # - deploy(version): deploy a new version
  # - commit(): validates currently deployed version
  # - rollback(): rollback currently deployed version
  # - createVersion(version): add a new developpement version
  # - restoreVersion(version): restores the existing developpement version
  #
  # In, addition of other 'method' events, the `versionChanged` event is triggered when the versions
  # list or current version changed, and an `initialized` event is triggered when the admin service 
  # get its state for the first time
  #
  # Instanciated as a singleton in `rheia.adminService` by the Router
  class AdminService
    _.extend @prototype, Backbone.Events

    # Indicates wether the administration is initialized or not
    initialized: false

    # **private**
    # Current deployement state. Contains:
    # @option current [String] current version, or null if no version 
    # @option deployed [String] name of the deployed version, null if no pending deployement 
    # @option author [String] email of the deployer,null if no pending deployement 
    # @option inProgress [Boolean] true if deployement still in progress
    # @option versions [Array<String>] list of existing versions (may be empty)
    _state: null

    # Service constructor
    constructor: ->
      # first, ask for deployement state
      sockets.admin.emit 'deployementState'
      sockets.admin.on 'deployement', @_onDeployementState

      sockets.admin.on 'deployementState-resp',  (err, state) =>
        return rheia.router.trigger 'serverError', err, method:"AdminService.deployementState" if err?
        @_state = state
        @initialized = true
        @trigger 'initialized'

      proxyMethod = (method) =>
        # registers the method to invoke corresponding server function
        AdminService::[method] = (args...) =>
          console.info "#{method} #{args.join ' '}..."
          args.splice 0, 0, method
          sockets.admin.emit.apply sockets.admin, args

        # register an error callback
        sockets.admin.on "#{method}-resp", (err) =>
          rheia.router.trigger 'serverError', err, method:"AdminService.#{method}" if err?

      proxyMethod method for method in ['deploy', 'commit', 'rollback', 'createVersion', 'restoreVersion']

    # Simple getter that indicate if a version is currently deploying
    # @return true if there is a deployement in progress
    isDeploying: =>
      @_state?.deploying

    # Simple getter that indicate if a deployement is ready for commit or rollback
    # @return true if there is a deployement in progress
    hasDeployed: =>
      @_state?.deployed?

    # Simple getter that indicate if the current version deployer is the connected player
    # @return true if there is a deployement in progress, and the deployer is the current player
    isDeployer: =>
      @_state?.deployed? and @_state?.author is rheia?.player?.email
      
    # Simple getter that indicates the current deployer
    # @return the current deployer email or null
    deployer: =>
      @_state?.author

    # Simple getter that indicates the current version
    # @return the current version or null
    current: =>
      @_state?.current

    # Simple getter for versions list
    # @return the array of versions names (may be empty)
    versions: =>
      @_state?.versions

    # **private**
    # Deployement state handler.
    #
    # @param state [String] current deployement state
    # @param step [Number] current step in deployement or error string of somthing failed
    # @param version [String] for `DEPLOY_START` and `VERSION_CREATED` state, the version name
    # @param author [String] for `DEPLOY_START` the deployer email
    _onDeployementState: (state, step, version, author) =>
      console.info "deployement: #{state} - #{step}"
      @trigger 'progress', state, step
      switch state 
        when 'DEPLOY_FAILED'
          rheia.router.trigger 'serverError', step, method:'AdminService.deploy'
          @trigger 'deploy', step
          @_state.deployed = null
          @_state.author = null
          @_state.deploying = false
        when 'COMMIT_FAILED'
          rheia.router.trigger 'serverError', step, method:'AdminService.commit'
          @trigger 'commit', step
          @_state.deployed = null
          @_state.author = null
        when 'ROLLBACK_FAILED'
          rheia.router.trigger 'serverError', step, method:'AdminService.rollback'
          @trigger 'rollback', step
          @_state.deployed = null
          @_state.author = null
        when 'VERSION_CREATED', 'VERSION_RESTORED'
          if @_state?.versions?
            @_state.versions.splice 0, 0, version if state is 'VERSION_CREATED'
            @_state.current = version
            @trigger 'versionChanged', null, @_state.versions, @_state.current
        when 'DEPLOY_START'
          @_state.deployed = version
          @_state.deploying = true
          @_state.author = author
        when 'DEPLOY_END'
          @_state.deploying = false
        when 'COMMIT_END', 'ROLLBACK_END'
          @_state.deployed = null
          @_state.author = null