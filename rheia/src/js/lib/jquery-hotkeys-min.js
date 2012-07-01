/*
* jQuery Hotkeys Plugin
* Copyright 2010, John Resig
* Dual licensed under the MIT or GPL Version 2 licenses.
*
* Based upon the plugin by Tzury Bar Yochay:
* http://github.com/tzuryby/hotkeys
*
* Original idea by:
* Binny V A, http://www.openjs.com/scripts/events/keyboard_shortcuts/
*/
(function(b){b.hotkeys={version:"0.8",specialKeys:{8:"backspace",9:"tab",13:"return",16:"shift",17:"ctrl",18:"alt",19:"pause",20:"capslock",27:"esc",32:"space",33:"pageup",34:"pagedown",35:"end",36:"home",37:"left",38:"up",39:"right",40:"down",45:"insert",46:"del",96:"0",97:"1",98:"2",99:"3",100:"4",101:"5",102:"6",103:"7",104:"8",105:"9",106:"*",107:"+",109:"-",110:".",111:"/",112:"f1",113:"f2",114:"f3",115:"f4",116:"f5",117:"f6",118:"f7",119:"f8",120:"f9",121:"f10",122:"f11",123:"f12",144:"numlock",145:"scroll",191:"/",224:"meta"},shiftNums:{"`":"~","1":"!","2":"@","3":"#","4":"$","5":"%","6":"^","7":"&","8":"*","9":"(","0":")","-":"_","=":"+",";":": ","'":'"',",":"<",".":">","/":"?","\\":"|"}};function a(d){if(typeof d.data!=="string"&&(d.data==null||typeof d.data!=="object"||!("keys" in d.data))){return}var c=d.handler;var f;var e=false;if(typeof d.data==="object"){f=d.data.keys.toLowerCase().split(" ");e=d.data.includeInputs}else{f=d.data.toLowerCase().split(" ")}d.handler=function(o){if(this!==o.target&&(!e&&(/textarea|select/i.test(o.target.nodeName)||o.target.type==="text"))){return}var j=o.type!=="keypress"&&b.hotkeys.specialKeys[o.which],p=String.fromCharCode(o.which).toLowerCase(),m,n="",h={};if(o.altKey&&j!=="alt"){n+="alt+"}if(o.ctrlKey&&j!=="ctrl"){n+="ctrl+"}if(o.metaKey&&!o.ctrlKey&&j!=="meta"){n+="meta+"}if(o.shiftKey&&j!=="shift"){n+="shift+"}if(j){h[n+j]=true}else{h[n+p]=true;h[n+b.hotkeys.shiftNums[p]]=true;if(n==="shift+"){h[b.hotkeys.shiftNums[p]]=true}}for(var k=0,g=f.length;k<g;k++){if(h[f[k]]){return c.apply(this,arguments)}}}}b.each(["keydown","keyup","keypress"],function(){b.event.special[this]={add:a}})})(jQuery);