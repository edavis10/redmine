/*
 noreferrer.js, version 0.1.2
 https://github.com/knu/noreferrer

 Copyright (c) 2011 Akinori MUSHA
 Licensed under the 2-clause BSD license.
*/
(function(){(function(){Prototype.Browser.WebKit||Event.observe(window,"load",function(){$$("a[href][rel~=noreferrer], area[href][rel~=noreferrer]").each(function(a){var f,c,i,d,j,g,k,e,l,h;c=a.href;if(Prototype.Browser.Opera)a.href="http://www.google.com/url?q="+encodeURIComponent(c),a.title||(a.title="Go to "+c);else{d=!1;i=function(){a.href="javascript:void(0)"};g=function(){a.href=c};h=["mouseout","mouseover","focus","blur"];e=0;for(l=h.length;e<l;e++)j=h[e],Event.observe(a,j,g);Event.observe(a,
"mousedown",function(a){if(a==null)a=window.event;Event.isMiddleClick(a)&&(d=!0)});Event.observe(a,"blur",function(){d=!1});Event.observe(a,"mouseup",function(a){if(a==null)a=window.event;Event.isMiddleClick(a)&&d&&(i(),Event.stop(a),d=!1,setTimeout(function(){alert("Middle clicking on this link is disabled to keep the browser from sending a referrer.");g()},500))});f=("<html>\n  <head>\n    <meta http-equiv='Refresh' content='0; URL="+c.escapeHTML()+"' />\n  </head>\n  <body>\n  </body>\n</html>").replace(/>\s+/g,
">");Prototype.Browser.IE?Event.observe(a,"click",function(a){var b;if(a==null)a=window.event;switch(b=this.target||"_self"){case "_self":case window.name:b=window;break;default:b=window.open(null,b)}b=b.document;b.clear();b.write(f);b.close();Event.stop(a);return!1}):(k="data:text/html;charset=utf-8,"+encodeURIComponent(f),Event.observe(a,"click",function(){this.href=k;return!0}))}})})})()}).call(this);
