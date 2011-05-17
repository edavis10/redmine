(function() {
  /*
    noreferrer.js, version 0.1.1

    Copyright (c) 2011 Akinori MUSHA

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
    OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.
  */
  /*
    Cross-browser support for HTML5's noreferrer link type.

    This version is for use with prototype.js.
  */  (function() {
    if (Prototype.Browser.WebKit) {
      return;
    }
    return Event.observe(window, 'load', function() {
      return $$('a[href][rel~=noreferrer], area[href][rel~=noreferrer]').each(function(a) {
        var body, href, kill_href, middlebutton, name, restore_href, uri, _i, _len, _ref;
        href = a.href;
        if (Prototype.Browser.Opera) {
          a.href = 'http://www.google.com/url?q=' + encodeURIComponent(href);
          a.title || (a.title = 'Go to ' + href);
          return;
        }
        middlebutton = false;
        kill_href = function(ev) {
          if (ev == null) {
            ev = window.event;
          }
          return a.href = 'javascript:void(0)';
        };
        restore_href = function(ev) {
          if (ev == null) {
            ev = window.event;
          }
          return a.href = href;
        };
        _ref = ['mouseout', 'mouseover', 'focus', 'blur'];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          name = _ref[_i];
          Event.observe(a, name, restore_href);
        }
        Event.observe(a, 'mousedown', function(ev) {
          if (ev == null) {
            ev = window.event;
          }
          if (Event.isMiddleClick(ev)) {
            return middlebutton = true;
          }
        });
        Event.observe(a, 'blur', function(ev) {
          if (ev == null) {
            ev = window.event;
          }
          return middlebutton = false;
        });
        Event.observe(a, 'mouseup', function(ev) {
          if (ev == null) {
            ev = window.event;
          }
          if (Event.isMiddleClick(ev) && middlebutton) {
            kill_href();
            Event.stop(ev);
            middlebutton = false;
            return setTimeout((function() {
              alert('Middle clicking on this link is disabled to keep the browser from sending a referrer.');
              return restore_href();
            }), 500);
          }
        });
        body = ("<html>\n  <head>\n    <meta http-equiv='Refresh' content='0; URL=" + (href.escapeHTML()) + "' />\n  </head>\n  <body>\n  </body>\n</html>").replace(/>\s+/g, '>');
        if (Prototype.Browser.IE) {
          return Event.observe(a, 'click', function(ev) {
            var doc, target, win;
            if (ev == null) {
              ev = window.event;
            }
            switch (target = this.target || '_self') {
              case '_self':
              case window.name:
                win = window;
                break;
              default:
                win = window.open(null, target);
            }
            doc = win.document;
            doc.clear();
            doc.write(body);
            doc.close();
            Event.stop(ev);
            return false;
          });
        } else {
          uri = "data:text/html;charset=utf-8," + (encodeURIComponent(body));
          return Event.observe(a, 'click', function(ev) {
            if (ev == null) {
              ev = window.event;
            }
            this.href = uri;
            return true;
          });
        }
      });
    });
  })();
}).call(this);
