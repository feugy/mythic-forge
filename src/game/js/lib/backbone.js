// Require-js wrapper for backbone
define(['./order!lib/underscore', './order!lib/jquery', './order!lib/backbone-0.9.2'], function(_, $){
  // Now that all the orignal source codes have ran and accessed each other
  // We can call noConflict() to remove them from the global name space
  // Require.js will keep a reference to them so we can use them in our modules
  _.noConflict();
  $.noConflict();
  return Backbone.noConflict();
});