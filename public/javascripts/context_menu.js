/* redMine - project management software
   Copyright (C) 2006-2008  Jean-Philippe Lang */

var observingContextMenuClick;

ContextMenu = Class.create();
ContextMenu.prototype = {
	initialize: function (url) {
	this.url = url;
	this.createMenu();

	if (!observingContextMenuClick) {
		Event.observe(document, 'click', this.Click.bindAsEventListener(this));
		Event.observe(document, 'contextmenu', this.RightClick.bindAsEventListener(this));
		observingContextMenuClick = true;
	}
	
	this.unselectAll();
	this.lastSelected = null;
	},
  
	RightClick: function(e) {
		this.hideMenu();
		// do not show the context menu on links
		if (Event.element(e).tagName == 'A') { return; }
		var tr = Event.findElement(e, 'tr');
		if (tr == document || tr == undefined  || !tr.hasClassName('hascontextmenu')) { return; }
		Event.stop(e);
		if (!this.isSelected(tr)) {
			this.unselectAll();
			this.addSelection(tr);
			this.lastSelected = tr;
		}
		this.showMenu(e);
	},

  Click: function(e) {
  	this.hideMenu();
  	if (Event.element(e).tagName == 'A' || Event.element(e).tagName == 'IMG') { return; }
    if (Event.isLeftClick(e) || (navigator.appVersion.match(/\bMSIE\b/))) {      
      var tr = Event.findElement(e, 'tr');
      if (tr!=null && tr!=document && tr.hasClassName('hascontextmenu')) {
        // a row was clicked, check if the click was on checkbox
        var box = Event.findElement(e, 'input');
        if (box!=document && box!=undefined) {
          // a checkbox may be clicked
          if (box.checked) {
            tr.addClassName('context-menu-selection');
          } else {
            tr.removeClassName('context-menu-selection');
          }
        } else {
          if (e.ctrlKey || e.metaKey) {
            this.toggleSelection(tr);
          } else if (e.shiftKey) {
            if (this.lastSelected != null) {
              var toggling = false;
              var rows = $$('.hascontextmenu');
              for (i=0; i<rows.length; i++) {
                if (toggling || rows[i]==tr) {
                  this.addSelection(rows[i]);
                }
                if (rows[i]==tr || rows[i]==this.lastSelected) {
                  toggling = !toggling;
                }
              }
            } else {
              this.addSelection(tr);
            }
          } else {
            this.unselectAll();
            this.addSelection(tr);
          }
          this.lastSelected = tr;
        }
      } else {
        // click is outside the rows
        var t = Event.findElement(e, 'a');
        if (t == document || t == undefined) {
          this.unselectAll();
        } else {
          if (Element.hasClassName(t, 'disabled') || Element.hasClassName(t, 'submenu')) {
            Event.stop(e);
          }
        }
      }
    }
    else{
      this.RightClick(e);
    }
  },
  
  createMenu: function() {
    if (!$('context-menu')) {
      var menu = document.createElement("div");
      menu.setAttribute("id", "context-menu");
      menu.setAttribute("style", "display:none;");
      document.getElementById("content").appendChild(menu);
    }
  },
  
  showMenu: function(e) {
    var mouse_x = Event.pointerX(e);
    var mouse_y = Event.pointerY(e);
    var render_x = mouse_x;
    var render_y = mouse_y;
    var dims;
    var menu_width;
    var menu_height;
    var window_width;
    var window_height;
    var max_width;
    var max_height;

    $('context-menu').style['left'] = (render_x + 'px');
    $('context-menu').style['top'] = (render_y + 'px');		
    Element.update('context-menu', '');

    new Ajax.Updater({success:'context-menu'}, this.url, 
      {asynchronous:true,
       method: 'get',
       evalScripts:true,
       parameters:Form.serialize(Event.findElement(e, 'form')),
       onComplete:function(request){
				 dims = $('context-menu').getDimensions();
				 menu_width = dims.width;
				 menu_height = dims.height;
				 max_width = mouse_x + 2*menu_width;
				 max_height = mouse_y + menu_height;
			
				 var ws = window_size();
				 window_width = ws.width;
				 window_height = ws.height;
			
				 /* display the menu above and/or to the left of the click if needed */
				 if (max_width > window_width) {
				   render_x -= menu_width;
				   $('context-menu').addClassName('reverse-x');
				 } else {
					 $('context-menu').removeClassName('reverse-x');
				 }
				 if (max_height > window_height) {
				   render_y -= menu_height;
				   $('context-menu').addClassName('reverse-y');
				 } else {
					 $('context-menu').removeClassName('reverse-y');
				 }
				 if (render_x <= 0) render_x = 1;
				 if (render_y <= 0) render_y = 1;
				 $('context-menu').style['left'] = (render_x + 'px');
				 $('context-menu').style['top'] = (render_y + 'px');
				 
         Effect.Appear('context-menu', {duration: 0.20});
         if (window.parseStylesheets) { window.parseStylesheets(); } // IE
      }})
  },
  
  hideMenu: function() {
    Element.hide('context-menu');
  },
  
  addSelection: function(tr) {
    tr.addClassName('context-menu-selection');
    this.checkSelectionBox(tr, true);
    this.clearDocumentSelection();
  },
  
  toggleSelection: function(tr) {
    if (this.isSelected(tr)) {
      this.removeSelection(tr);
    } else {
      this.addSelection(tr);
    }
  },
  
  removeSelection: function(tr) {
    tr.removeClassName('context-menu-selection');
    this.checkSelectionBox(tr, false);
  },
  
  unselectAll: function() {
    var rows = $$('.hascontextmenu');
    for (i=0; i<rows.length; i++) {
      this.removeSelection(rows[i]);
    }
  },
  
  checkSelectionBox: function(tr, checked) {
  	var inputs = Element.getElementsBySelector(tr, 'input');
  	if (inputs.length > 0) { inputs[0].checked = checked; }
  },
  
  isSelected: function(tr) {
    return Element.hasClassName(tr, 'context-menu-selection');
  },
  
  clearDocumentSelection: function() {
    if (document.selection) {
      document.selection.clear(); // IE
    } else {
      window.getSelection().removeAllRanges();
    }
  }
}

function toggleIssuesSelection(el) {
	var boxes = el.getElementsBySelector('input[type=checkbox]');
	var all_checked = true;
	for (i = 0; i < boxes.length; i++) { if (boxes[i].checked == false) { all_checked = false; } }
	for (i = 0; i < boxes.length; i++) {
		if (all_checked) {
			boxes[i].checked = false;
			boxes[i].up('tr').removeClassName('context-menu-selection');
		} else if (boxes[i].checked == false) {
			boxes[i].checked = true;
			boxes[i].up('tr').addClassName('context-menu-selection');
		}
	}
}

function window_size() {
    var w;
    var h;
    if (window.innerWidth) {
	w = window.innerWidth;
	h = window.innerHeight;
    } else if (document.documentElement) {
	w = document.documentElement.clientWidth;
	h = document.documentElement.clientHeight;
    } else {
	w = document.body.clientWidth;
	h = document.body.clientHeight;
    }
    return {width: w, height: h};
}
