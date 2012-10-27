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
'use strict'

var locale = localStorage.getItem('locale') || navigator.language;

// configure requireJs
require.config({
  paths: {
    'jquery': 'lib/jquery-1.8.2-min',
    'i18n': 'lib/i18n-2.0.1-min',
    'text': 'lib/text-2.0.0-min',
    'nls': '../nls',
    'template': '../template',
    'images': '../style/images'
  }, shim: {
    'jquery-ui': {deps: ['jquery']}
  },
  i18n: {
    locale: locale
  }
});

define(['jquery', 'i18n!nls/common'], function($, i18n) {

  $.fn.extend({
    // Utilities to manipulate class on svg nodes: $.addClass() and $.removeClass() doesn't work 
    addClassSvg: function(newClass) {
      var value = this.attr('class') || '';
      if ((' '+value+' ').indexOf(' '+newClass+' ') === -1) {
        this.attr('class', (value+' '+newClass).trim());
      }
      return this;
    },

    removeClassSvg: function(value) { 
      this.attr('class', (' '+this.attr('class')+' ').replace(' '+value+' ', ' ').trim());
      return this;
    }
  });

  // Display template inside body, refresh titles
  var displayTemplate = function(template, pageName) {
    $('.main').empty().append(template);
    $('.title').html(i18n[pageName]);
    document.title = i18n[pageName];
  };

  var displayIntro = function(template) {
    displayTemplate(template, 'intro');
    // adds schemas
    require(['text!images/scheme1.svg!strip',
      'text!images/scheme2.svg!strip',
      'text!images/scheme3.svg!strip'
    ], function(scheme1, scheme2, scheme3) {

      // scheme
      $('#scheme1').append(scheme1);
      $('#scheme2').append(scheme2);
      $('#scheme3').append(scheme3);

      // add animation in schemes 
      $('.scheme').each(function() {
        // operates inside a given scheme
        var scheme = $(this);
        // each object with shown data attribute will trigger an animation
        scheme.find('[data-shown]').each(function() {
          var trigger = $(this);
          // some objects will be shown, some other will be masked
          var shown = trigger.data('shown');
          var masked = trigger.data('masked');
          trigger.hover(function(){
            scheme.find(shown).addClassSvg('shown').removeClassSvg('hidden');
            scheme.find(masked).addClassSvg('masked').removeClassSvg('shown');
            // shown also details not present inside the scheme
            $('#'+trigger.attr('id')+'-details').addClass('shown').removeClass('hidden');
          }, function(){
            scheme.find(shown).addClassSvg('hidden').removeClassSvg('shown');
            scheme.find(masked).addClassSvg('shown').removeClassSvg('masked');
            // hides also details not present inside the scheme
            $('#'+trigger.attr('id')+'-details').addClass('hidden').removeClass('shown');
          });
        });
      });

    });
  };

  $(function() {
    // wire locale buttons
    $('.locale-bar img').each(function(){
      var button = $(this);
      button.on('click', function(event) {
        event.preventDefault();
        // changes the stored locale and refresh page
        localStorage.setItem('locale', button.data('locale'));
        window.location = window.location;
      })
    });

    // get the localized intro
    require(['text!template/'+locale+'/intro.html'], displayIntro, function(err) {
      if (locale.indexOf('-') !== -1) {
        // no localized page found: try to restrict to main language
        locale = locale.replace(/-.+$/, '');
        require(['text!template/'+locale+'/intro.html'], displayIntro, function(err) {
          // no localized page: use root page
          require(['text!template/intro.html'], displayIntro);
        });
      } else {
        // no localized page: use root page
        require(['text!template/intro.html'], displayIntro);
      }
    });

  });
});