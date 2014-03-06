
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
var authorizedKeys, coffee, express, fs, gameService, http, logger, notifier, path, stylus, url, utils;

logger = require('../util/logger').getLogger('web');

express = require('express');

path = require('path');

url = require('url');

fs = require('fs');

http = require('http');

coffee = require('coffee-script');

utils = require('../util/common');

stylus = require('stylus');

gameService = require('../service/GameService').get();

notifier = require('../service/Notifier').get();

authorizedKeys = {};

notifier.on(notifier.NOTIFICATION, function(event, stateOrEmail, playerOrkey) {
  var email, key, _results;
  if (event !== 'admin-connect' && event !== 'players') {
    return;
  }
  if (event === 'admin-connect') {
    logger.debug("allow static connection from player " + stateOrEmail);
    return authorizedKeys[playerOrkey] = stateOrEmail;
  } else if (stateOrEmail === 'disconnect') {
    _results = [];
    for (key in authorizedKeys) {
      email = authorizedKeys[key];
      if (!(email === playerOrkey.email)) {
        continue;
      }
      logger.debug("deny static connection from player " + playerOrkey.email);
      delete authorizedKeys[key];
      break;
    }
    return _results;
  }
});

module.exports = function(app) {
  var configureRIA, registerConf, _ref;
  if (app == null) {
    app = null;
  }
  if (app == null) {
    app = express();
  }
  registerConf = function(base) {
    logger.debug("register configuration endpoint for client " + base);
    return app.get("" + base + "/conf.js", function(req, res, next) {
      var locale;
      locale = req.params.locale || null;
      return gameService.getConf(base, req.params.locale || null, function(err, conf) {
        if (err != null) {
          return res.send(err, 500);
        }
        res.header('Content-Type', 'application/javascript; charset=UTF-8');
        return res.send("window.conf = " + (JSON.stringify(conf)));
      });
    });
  };
  configureRIA = function(base, rootFolder, isStatic, securedRedirect) {
    if (isStatic == null) {
      isStatic = false;
    }
    if (securedRedirect == null) {
      securedRedirect = null;
    }
    logger.debug("register RIA for " + base + " at root " + rootFolder + " (secured: " + securedRedirect + " static: " + isStatic + ")");
    if (securedRedirect != null) {
      app.get(new RegExp("^" + base), function(req, res, next) {
        var key, _ref;
        key = (_ref = req.cookies) != null ? _ref.key : void 0;
        if (key == null) {
          return res.redirect("" + securedRedirect + "?redirect=" + (encodeURIComponent(req.url)));
        }
        if (key in authorizedKeys) {
          return next();
        }
        res.clearCookie('key');
        return res.redirect("" + securedRedirect + "?error=" + (encodeURIComponent("" + base + " not authorized")));
      });
    }
    registerConf(base);
    if (!isStatic) {
      app.get(new RegExp("^" + base + "/(.*)\.js$"), function(req, res, next) {
        var file;
        file = path.join(rootFolder, "" + req.params[0] + ".coffee");
        return fs.readFile(file, (function(_this) {
          return function(err, content) {
            var exc;
            if (err != null) {
              return next('ENOENT' === err.code ? null : err);
            }
            try {
              res.header('Content-Type', 'application/javascript');
              return res.send(coffee.compile(content.toString()));
            } catch (_error) {
              exc = _error;
              logger.error("Failed to compile " + file + ": " + exc);
              return res.send(exc.message, 500);
            }
          };
        })(this));
      });
      app.get(new RegExp("^" + base + "/(.*)\.css$"), function(req, res, next) {
        var file, parent;
        file = path.join(rootFolder, "" + req.params[0] + ".styl");
        parent = path.dirname(file);
        return fs.readFile(file, (function(_this) {
          return function(err, content) {
            if (err != null) {
              return next('ENOENT' === err.code ? null : err);
            }
            return stylus(content.toString(), {
              compress: true
            }).set('paths', [parent]).render(function(err, css) {
              if (err != null) {
                logger.error("Failed to compile " + file + ": " + err);
                return res.send(err, 500);
              }
              res.header('Content-Type', 'text/css');
              return res.send(css);
            });
          };
        })(this));
      });
    }
    app.get(new RegExp("^" + base + ".*(?!\\.\\w+)$"), function(req, res, next) {
      var pathname;
      if (req.url === ("" + base)) {
        return res.redirect("" + base + "/");
      }
      pathname = url.parse(req.url).pathname.slice(base.length + 1) || 'index.html';
      return fs.exists(path.join(rootFolder, pathname), (function(_this) {
        return function(exists) {
          if (exists) {
            return next();
          }
          fs.createReadStream(path.join(rootFolder, 'index.html')).on('error', function() {
            return res.send(404);
          }).pipe(res);
          return res.header('Content-Type', 'text/html; charset=UTF-8');
        };
      })(this));
    });
    return app.use("" + base, express["static"](rootFolder, {
      maxAge: 0
    }));
  };
  app.use(express.cookieParser(utils.confKey('server.cookieSecret')));
  app.use('/images', express["static"](utils.confKey('images.store'), {
    maxAge: 1814400000
  }));
  app.use(express["static"]('docs'));
  app.use(express.compress({
    level: 9
  }));
  configureRIA('/game', utils.confKey('game.client.production'), true);
  configureRIA('/dev', utils.confKey('game.client.dev'), false, process.env.NODE_ENV === 'test' ? null : '/rheia/login');
  if ((_ref = process.env.NODE_ENV) === 'buyvm' || _ref === 'simons') {
    configureRIA('/rheia', './rheia-min', true);
  } else {
    configureRIA('/rheia', './rheia');
  }
  return app;
};
