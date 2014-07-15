/*
html5slider - a JS implementation of <input type=range> for Firefox 4 and up
https://github.com/fryn/html5slider

Copyright (c) 2010-2011 Frank Yan, <http://frankyan.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Special change: do not add focus color
*/

(function(){function i(){Array.forEach(document.querySelectorAll("input[type=range]"),l);document.addEventListener("DOMNodeInserted",j,true)}function j(a){k(a.target);if(a.target.querySelectorAll)Array.forEach(a.target.querySelectorAll("input"),k)}function k(a,b){if(a.localName!="input"||a.type=="range");else if(a.getAttribute("type")=="range")l(a);else if(!b)setTimeout(k,0,a,true)}function l(a){function w(a){k=true;setTimeout(function(){k=false},0);if(a.button||!s)return;var b=parseFloat(getComputedStyle(this,0).width);var c=(b-e.width)/s;if(!c)return;var d=a.clientX-this.getBoundingClientRect().left-e.width/2-(t-p)*c;if(Math.abs(d)>e.radius){j=true;this.value-=-d/c}n=t;o=a.clientX;this.addEventListener("mousemove",x,true);this.addEventListener("mouseup",y,true)}function x(a){var b=parseFloat(getComputedStyle(this,0).width);var c=(b-e.width)/s;if(!c)return;n+=(a.clientX-o)/c;o=a.clientX;j=true;this.value=n}function y(){this.removeEventListener("mousemove",x,true);this.removeEventListener("mouseup",y,true)}function z(a){if(a.keyCode>36&&a.keyCode<41){A.call(this);j=true;this.value=t+(a.keyCode==38||a.keyCode==39?r:-r)}}function A(){/*if(!k)this.style.boxShadow=!d?"0 0 0 2px #fb0":"0 0 2px 1px -moz-mac-focusring, inset 0 0 1px -moz-mac-focusring"*/}function B(){/*this.style.boxShadow=""*/}function C(a){return!isNaN(a)&&+a==parseFloat(a)}function D(){p=C(a.min)?+a.min:0;q=C(a.max)?+a.max:100;if(q<p)q=p>100?p:100;r=C(a.step)&&a.step>0?+a.step:1;s=q-p;F(true)}function E(){if(!b&&!i)t=a.getAttribute("value");if(!C(t))t=(p+q)/2;t=Math.round((t-p)/r)*r+p;if(t<p)t=p;else if(t>q)t=p+~~(s/r)*r}function F(b){E();if(j&&t!=l)a.dispatchEvent(h);j=false;if(!b&&t==l)return;l=t;var c=s?(t-p)/s*100:0;var d="-moz-element(#__sliderthumb__) "+c+"% no-repeat, ";m(a,{background:d+f})}var b,i,j,k,l,n,o;var p,q,r,s,t=a.value;if(!c){c=document.body.appendChild(document.createElement("hr"));m(c,{"-moz-appearance":d?"scale-horizontal":"scalethumb-horizontal",display:"block",visibility:"visible",opacity:1,position:"fixed",top:"-999999px"});document.mozSetImageElement("__sliderthumb__",c)}var u=function(){return""+t};var v=function G(c){t=""+c;b=true;F();delete a.value;a.value=t;a.__defineGetter__("value",u);a.__defineSetter__("value",G)};a.__defineGetter__("value",u);a.__defineSetter__("value",v);a.__defineGetter__("type",function(){return"range"});["min","max","step"].forEach(function(b){if(a.hasAttribute(b))i=true;a.__defineGetter__(b,function(){return this.hasAttribute(b)?this.getAttribute(b):""});a.__defineSetter__(b,function(a){a===null?this.removeAttribute(b):this.setAttribute(b,a)})});a.readOnly=true;m(a,g);D();a.addEventListener("DOMAttrModified",function(a){if(a.attrName=="value"&&!b){t=a.newValue;F()}else if(~["min","max","step"].indexOf(a.attrName)){D();i=true}},true);a.addEventListener("mousedown",w,true);a.addEventListener("keydown",z,true);a.addEventListener("focus",A,true);a.addEventListener("blur",B,true)}function m(a,b){for(var c in b)a.style.setProperty(c,b[c],"important")}var a=document.createElement("input");try{a.type="range";if(a.type=="range")return}catch(b){return}if(!document.mozSetImageElement||!("MozAppearance"in a.style))return;var c;var d=navigator.platform=="MacIntel";var e={radius:d?9:6,width:d?22:12,height:d?16:20};var f="-moz-linear-gradient(top, transparent "+(d?"6px, #999 6px, #999 7px, #ccc 9px, #bbb 11px, #bbb 12px, transparent 12px":"9px, #999 9px, #bbb 10px, #fff 11px, transparent 11px")+", transparent)";var g={"min-width":e.width+"px","min-height":e.height+"px","max-height":e.height+"px",padding:0,border:0,"border-radius":0,cursor:"default","text-indent":"-999999px"};var h=document.createEvent("HTMLEvents");h.initEvent("change",true,false);if(document.readyState=="loading")document.addEventListener("DOMContentLoaded",i,true);else i()})()