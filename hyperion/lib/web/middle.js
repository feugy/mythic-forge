
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
var GoogleStrategy, LocalStrategy, LoggerFactory, TwitterStrategy, adminNS, adminService, app, authoringService, caPath, certPath, checkAdmin, corser, deployementService, exposeMethods, express, fs, gameService, getRedirect, http, https, imagesService, io, keyPath, logger, moment, noSecurity, notifier, opt, passport, playerService, registerOAuthProvider, ruleService, searchService, server, updateNS, urlParse, utils, watcher, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __slice = [].slice;

express = require('express');

_ = require('underscore');

utils = require('../util/common');

http = require('http');

https = require('https');

fs = require('fs');

passport = require('passport');

moment = require('moment');

urlParse = require('url').parse;

corser = require('corser');

GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;

TwitterStrategy = require('passport-twitter').Strategy;

LocalStrategy = require('passport-local').Strategy;

gameService = require('../service/GameService').get();

playerService = require('../service/PlayerService').get();

adminService = require('../service/AdminService').get();

imagesService = require('../service/ImagesService').get();

searchService = require('../service/SearchService').get();

authoringService = require('../service/AuthoringService').get();

deployementService = require('../service/DeployementService').get();

ruleService = require('../service/RuleService').get();

watcher = require('../model/ModelWatcher').get();

notifier = require('../service/Notifier').get();

LoggerFactory = require('../util/logger');

logger = LoggerFactory.getLogger('web');

app = null;

certPath = utils.confKey('ssl.certificate', null);

keyPath = utils.confKey('ssl.key', null);

app = express();

noSecurity = process.env.NODE_ENV === 'test';

app.use(express.cookieParser(utils.confKey('server.cookieSecret')));

app.use(express.urlencoded());

app.use(express.json());

app.use(express.methodOverride());

app.use(corser.create({
  origins: ["http://" + (utils.confKey('server.host')) + ":" + (utils.confKey('server.staticPort', '')), "http://" + (utils.confKey('server.host')) + ":" + (utils.confKey('server.bindingPort', ''))],
  methods: ['GET', 'HEAD', 'POST', 'DELETE', 'PUT']
}));

app.use(express.session({
  secret: 'mythic-forge'
}));

app.use(passport.initialize());

if ((certPath != null) && (keyPath != null)) {
  caPath = utils.confKey('ssl.ca', null);
  logger.info("use SSL certificates: " + certPath + ", " + keyPath + " and " + (caPath != null ? caPath : 'no certificate chain'));
  opt = {
    cert: fs.readFileSync(certPath).toString(),
    key: fs.readFileSync(keyPath).toString()
  };
  if (caPath != null) {
    opt.ca = fs.readFileSync(caPath).toString();
  }
  server = https.createServer(opt, app);
} else {
  server = http.createServer(app);
}

io = require('socket.io').listen(server, {
  logger: LoggerFactory.getLogger('webSocket')
});

io.set('log level', 0);

getRedirect = function(req) {
  var url;
  url = urlParse(req.headers.referer != null ? req.headers.referer : "http://" + req.headers.host);
  return "http://" + (utils.confKey('server.host')) + ":" + (utils.confKey('server.bindingPort', utils.confKey('server.staticPort'))) + url.pathname;
};

exposeMethods = function(service, socket, connected, except) {
  if (connected == null) {
    connected = [];
  }
  if (except == null) {
    except = [];
  }
  return socket.get('email', function(err, email) {
    var method, _results;
    if (noSecurity) {
      email = 'admin';
    }
    _results = [];
    for (method in service.__proto__) {
      if (__indexOf.call(except, method) < 0) {
        _results.push((function(method) {
          return socket.on(method, function() {
            var args, originalArgs, reqId;
            playerService.activity(email);
            originalArgs = Array.prototype.slice.call(arguments);
            args = originalArgs.slice(1);
            reqId = originalArgs[0];
            if (__indexOf.call(connected, method) >= 0) {
              args.push(email);
            }
            args.push(function() {
              var returnArgs;
              logger.debug("returning " + method + " response " + (arguments[0] != null ? arguments[0] : ''));
              returnArgs = Array.prototype.slice.call(arguments);
              returnArgs.splice(0, 0, "" + method + "-resp", reqId);
              if (utils.isA(returnArgs != null ? returnArgs[2] : void 0, Error)) {
                returnArgs[2] = returnArgs[2].message;
              }
              return socket.emit.apply(socket, returnArgs);
            });
            logger.debug("processing " + method + " message with arguments " + originalArgs);
            return service[method].apply(service, args);
          });
        })(method));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  });
};

checkAdmin = function(handshakeData, callback) {
  if (noSecurity) {
    return callback(null, true);
  }
  return playerService.getByEmail(handshakeData != null ? handshakeData.playerEmail : void 0, false, function(err, player) {
    if (err != null) {
      return callback("Failed to consult connected player: " + err);
    }
    return callback(null, player != null ? player.isAdmin : void 0);
  });
};

registerOAuthProvider = function(provider, strategy, verify, scopes) {
  var args, redirects;
  if (scopes == null) {
    scopes = null;
  }
  if (scopes != null) {
    passport.use(new strategy({
      clientID: utils.confKey("authentication." + provider + ".id"),
      clientSecret: utils.confKey("authentication." + provider + ".secret"),
      callbackURL: "" + (certPath != null ? 'https' : 'http') + "://" + (utils.confKey('server.host')) + ":" + (utils.confKey('server.bindingPort', utils.confKey('server.apiPort'))) + "/auth/" + provider + "/callback"
    }, verify));
    args = {
      session: false,
      scope: scopes
    };
  } else {
    passport.use(new strategy({
      consumerKey: utils.confKey("authentication." + provider + ".id"),
      consumerSecret: utils.confKey("authentication." + provider + ".secret"),
      callbackURL: "" + (certPath != null ? 'https' : 'http') + "://" + (utils.confKey('server.host')) + ":" + (utils.confKey('server.bindingPort', utils.confKey('server.apiPort'))) + "/auth/" + provider + "/callback"
    }, verify));
    args = {};
  }
  redirects = [];
  app.get("/auth/" + provider, function(req, res, next) {
    var id;
    id = "req" + (_.uniqueId());
    redirects[id] = getRedirect(req);
    if (scopes != null) {
      args.state = id;
    } else {
      req.session.state = id;
    }
    return passport.authenticate(provider, args)(req, res, next);
  });
  return app.get("/auth/" + provider + "/callback", function(req, res, next) {
    var redirect, state;
    if (scopes != null) {
      state = req.param('state');
    } else {
      state = req.session.state;
    }
    redirect = redirects[state];
    return passport.authenticate(provider, function(err, token) {
      if (err != null) {
        return res.redirect("" + redirect + "?error=" + err);
      }
      res.redirect("" + redirect + "?token=" + token);
      return req.session.destroy();
    })(req, res, next);
  });
};

io.configure(function() {
  return io.set('authorization', function(handshakeData, callback) {
    var token;
    if (noSecurity) {
      return callback(null, true);
    }
    token = handshakeData.query.token;
    if ('string' !== utils.type(token) || token.length === 0) {
      return callback('No token provided');
    }
    return playerService.getByToken(token, function(err, player) {
      if (err != null) {
        return callback(err);
      }
      if (player != null) {
        logger.info("Player " + player.email + " connected with token " + token);
        handshakeData.playerEmail = player.email;
      }
      return callback(null, player != null);
    });
  });
});

io.on('connection', function(socket) {
  var email, key, _ref;
  email = (_ref = socket.manager.handshaken[socket.id]) != null ? _ref.playerEmail : void 0;
  if (noSecurity) {
    email = 'admin';
  }
  playerService.activity(email);
  socket.set('email', email);
  key = null;
  playerService.getByEmail(email, false, function(err, player) {
    if ((err != null) || player === null) {
      return logger.warn("Failed to retrieve player " + email + " to set its socket id: " + (err || 'no player found'));
    }
    player.socketId = socket.id;
    if (player.isAdmin) {
      key = utils.generateToken(24);
      notifier.notify('admin-connect', email, key);
    }
    return player.save(function(err) {
      if (err != null) {
        return logger.warn("Failed to set socket id of player " + email + ": " + err);
      }
    });
  });
  socket.on('getConnected', function(callback) {
    return socket.get('email', function(err, value) {
      if (err != null) {
        return callback(err);
      }
      return playerService.getByEmail(value, false, (function(_this) {
        return function(err, player) {
          if ((key != null) && (player != null)) {
            player.key = key;
          }
          return callback(err, player);
        };
      })(this));
    });
  });
  return socket.on('logout', function() {
    return socket.get('email', function(err, value) {
      return playerService.disconnect(value, 'logout');
    });
  });
});

io.of('/game').on('connection', function(socket) {
  return exposeMethods(gameService, socket, ['resolveRules', 'executeRule']);
});

adminNS = io.of('/admin').authorization(checkAdmin).on('connection', function(socket) {
  exposeMethods(adminService, socket, ['save', 'remove']);
  exposeMethods(imagesService, socket);
  exposeMethods(searchService, socket);
  exposeMethods(authoringService, socket, ['move'], ['readRoot', 'save', 'remove']);
  exposeMethods(deployementService, socket, ['deploy', 'commit', 'rollback', 'createVersion']);
  exposeMethods(ruleService, socket, [], ['export', 'resolve', 'execute']);
  socket.on('kick', function(email) {
    return playerService.disconnect(email, 'kicked', function() {});
  });
  return socket.on('connectedList', function(reqId) {
    return socket.emit('connectedList-resp', reqId, playerService.connectedList);
  });
});

updateNS = io.of('/updates');

watcher.on('change', function(operation, className, instance) {
  logger.debug("broadcast of " + operation + " on " + instance.id + " (" + className + ")");
  return updateNS.emit(operation, className, instance);
});

notifier.on(notifier.NOTIFICATION, function() {
  var details, event, scope, socket, _ref, _ref1;
  scope = arguments[0], event = arguments[1], details = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
  if (event === 'disconnect') {
    socket = io != null ? (_ref = io.sockets) != null ? (_ref1 = _ref.sockets) != null ? _ref1[details[0].socketId] : void 0 : void 0 : void 0;
    if (socket == null) {
      return;
    }
    socket.disconnect();
    logger.info("disconnect user " + details[0].email + " for " + details[1]);
  }
  if (scope === 'time') {
    return updateNS != null ? updateNS.emit('change', 'time', details[0]) : void 0;
  } else {
    return adminNS != null ? adminNS.emit.apply(adminNS, [scope, event].concat(details)) : void 0;
  }
});

LoggerFactory.on('log', function(details) {
  var err;
  try {
    return adminNS != null ? adminNS.emit('log', details) : void 0;
  } catch (_error) {
    err = _error;
    return process.stderr.write("failed to send log to client: " + err);
  }
});

passport.use(new LocalStrategy(playerService.authenticate));

registerOAuthProvider('google', GoogleStrategy, playerService.authenticatedFromGoogle, ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']);

registerOAuthProvider('twitter', TwitterStrategy, playerService.authenticatedFromTwitter);

app.post('/auth/login', function(req, res, next) {
  return passport.authenticate('local', function(err, token, details) {
    if (token === false) {
      err = details.message;
    }
    return res.format({
      html: function() {
        return res.redirect("" + (getRedirect(req)) + "?" + (err != null ? "error=" + err : "token=" + token));
      },
      json: function() {
        var result;
        result = {
          redirect: getRedirect(req)
        };
        if (err != null) {
          result.error = err;
        } else {
          result.token = token;
        }
        return res.json(result);
      }
    });
  })(req, res, next);
});

app.get('/konami', function(req, res) {
  return res.send('<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>');
});

module.exports = {
  server: server,
  app: app
};
