
/*
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
 */
'use strict';
var Executable, LoggerFactory, cluster, logger, modelWatcher, notifier, pathUtils, ready, worker, _,
  __slice = [].slice;

cluster = require('cluster');

if (cluster.isMaster) {
  return;
}

pathUtils = require('path');

_ = require('underscore');

modelWatcher = require('../../model/ModelWatcher').get();

notifier = require('../Notifier').get();

Executable = require('../../model/Executable');

LoggerFactory = require('../../util/logger');

logger = LoggerFactory.getLogger('worker');

ready = false;

Executable.resetAll(false, function(err) {
  if (err == null) {
    ready = true;
    return process.emit('rulesInitialized');
  }
  logger.error("Failed to initialize worker's executable cache: " + err);
  return process.exit(1);
});

process.on('uncaughtException', function(err) {
  err = worker._errMsg != null ? worker._errMsg + err.stack : err.stack != null ? err.stack : err;
  logger.warn("worker " + process.pid + " caught unexpected exception: " + err);
  if ((err != null ? err.code : void 0) !== 'EPIPE') {
    process.send({
      method: worker._method,
      id: worker._id,
      results: [err]
    });
  }
  return process.exit(0);
});

worker = require(pathUtils.resolve(__dirname, process.env.module));

process.on('message', function(msg) {
  if (!ready) {
    if ((msg != null ? msg.method : void 0) in worker) {
      process.send({
        method: msg.method,
        id: msg.id,
        results: ['worker not ready']
      });
    }
    return;
  }
  if ((msg != null ? msg.event : void 0) === 'change') {
    return modelWatcher.emit.apply(modelWatcher, ['change'].concat(msg.args || []));
  } else if ((msg != null ? msg.event : void 0) === 'executableReset') {
    ready = false;
    return Executable.resetAll(false, function(err) {
      if (err == null) {
        return ready = true;
      }
      logger.error("Failed to initialize worker's executable cache: " + err);
      return process.exit(1);
    });
  } else if ((msg != null ? msg.method : void 0) in worker) {
    worker._method = msg.method;
    worker._id = msg.id;
    return worker[msg.method].apply(worker, (msg.args || []).concat(function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return process.send({
        method: msg.method,
        id: msg.id,
        results: args
      });
    }));
  }
});

modelWatcher.on('change', function(operation, className, changes, wId) {
  var err;
  if (wId != null) {
    return;
  }
  try {
    return process.send({
      event: 'change',
      args: [operation, className, changes, process.pid]
    });
  } catch (_error) {
    err = _error;
    console.error("worker " + process.pid + ", module " + process.env.module + " failed to relay change due to: " + err);
    return process.exit(1);
  }
});

notifier.on(notifier.NOTIFICATION, function() {
  var args, err;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  try {
    return process.send({
      event: notifier.NOTIFICATION,
      args: args,
      from: process.pid
    });
  } catch (_error) {
    err = _error;
    console.error("worker " + process.pid + ", module " + process.env.module + " failed to relay notification due to: " + err);
    return process.exit(1);
  }
});

LoggerFactory.on('log', function(data) {
  var err;
  try {
    return process.send({
      event: 'log',
      args: data,
      from: process.pid
    });
  } catch (_error) {
    err = _error;
    return process.stderr.write("failed to send log to master process: " + err);
  }
});
