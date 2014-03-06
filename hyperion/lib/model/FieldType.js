
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
var FieldType, conn, logger, modelUtils, typeFactory;

typeFactory = require('./typeFactory');

conn = require('./connection');

logger = require('../util/logger').getLogger('model');

modelUtils = require('../util/model');

FieldType = typeFactory('FieldType', {
  descImage: {
    type: String
  },
  images: {
    type: [],
    "default": function() {
      return [];
    }
  }
}, {
  hasImages: true,
  middlewares: {
    save: function(next) {
      return modelUtils.addConfKey(this.id, 'names', this.id, logger, next);
    }
  }
});

module.exports = conn.model('fieldType', FieldType);
