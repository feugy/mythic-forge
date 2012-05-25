(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  define(['lib/backbone', 'connector'], function(Backbone, connector) {
    var Item, cache;
    cache = {};
    Item = (function(_super) {

      __extends(Item, _super);

      Item.name = 'Item';

      Item._fetchRunning = false;

      Item.fetchByCoord = function(lowX, lowY, upX, upY) {
        if (Item._fetchRunning) {
          return;
        }
        Item._fetchRunning = true;
        console.log("Consult map items between " + lowX + ":" + lowY + " and " + upX + ":" + upY);
        return connector.gameSocket.emit('consultMap', lowX, lowY, upX, upY);
      };

      Item._onConsultMap = function(err, rawItems) {
        var item, items, rawItem, _i, _len;
        if (err != null) {
          return console.err("Fail to retrieve map content: " + err);
        }
        console.log("" + rawItems.length + " map item(s) received");
        items = [];
        for (_i = 0, _len = rawItems.length; _i < _len; _i++) {
          rawItem = rawItems[_i];
          item = new Item(rawItem);
          cache[item.get('_id')] = item;
          items.push(item);
        }
        connector.dispatcher.trigger('onFetchByCoord', items);
        return Item._fetchRunning = false;
      };

      function Item(attributes) {
        Item.__super__.constructor.call(this, attributes);
        this.idAttribute = '_id';
      }

      return Item;

    }).call(this, Backbone.Model);
    connector.gameSocket.on('consultMap-resp', Item._onConsultMap);
    return Item;
  });

}).call(this);
