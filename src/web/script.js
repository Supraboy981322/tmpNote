"use strict";

//set later
var note_info = undefined; //may use for more than rendering the page 
var note_file = null;
var server_info = undefined;

//setup the page
(async function() {
  //remove "enable JavaScript" warning
  document.getElementById("js_warn").remove();

  //some timing trickery to get animation timing perfect
  setTimeout(() => { //(only tested on FireFox)
    document.querySelector(".collapsed").removeAttribute("class");
  }, -1);
  
  //when minifying the JS, the fn names change
  {for (const selector of [
    '[onclick="newNote();"]',
    '[onclick="view_from_new(this);"]',
    '[onclick="new_from_view();"]',
    '[onclick="new_note()"]',
  ]) { //get element
    let btn = document.querySelector(selector);
    //if the element exists (JS is shared between pages)
    if (btn != null || btn != undefined) {
      //correct the onclick attr 
      btn.onclick = (() => { //switch on og fn name
        let fn = selector.split('"')[1].split('"')[0];
        switch (fn) {
         case "newNote();": return newNote;
         case "view_from_new(this);": return () => { return view_from_new(btn) };
         case "new_from_view();": return new_from_view;
         default: //in case I add to array but forget the switch statement
          console.error(`you forgot to add ${fn} to a switch statement`);
          return undefined;
        }
      })();
    }
  }}

  const server_info_elm = document.getElementById("server_info");
  if (server_info_elm != null) {
    server_info = JSON.parse(server_info_elm.innerText);
    console.log(server_info.use_encryption);
  }
  
  if (document.querySelector("body>div>h1>.page").innerText == "new") {
    //create tab element
    let tab = document.createElement("div");
    tab.setAttribute("class", "tab");
    tab.setAttribute("is_open", "false");
    tab.setAttribute("which", "new_note");
    tab.innerText = "\u2630";
    tab.onclick = () => { return tab_btn(tab) };
    document.querySelector("#note").before(tab);
  }

  //if the '#note_info' element exists, it's a file 
  const note_info_elm = document.getElementById("note_info");
  if (note_info_elm != null) {
    //(it's JSON')
    note_info = JSON.parse(note_info_elm.innerText);
    if (note_info.is_file) {
      //use a default name if none given by server
      if (note_info.file_name === null) note_info = "untitled_tmpNote";
      //setup for file page
      const file_elm = document.getElementById("file");

      //warn if image
      if (note_info.class == "Picture") {
        //container so the child elements are centered vertically
        let warning_container = document.createElement("div");
        warning_container.setAttribute("id", "warning_container");
        warning_container.setAttribute("class", "full-screen");

        //another container so the child elements the
        //  'display: block;' attribute actually does something 
        let warning = document.createElement("div");
        warning_container.appendChild(warning);

        //warning text
        let txt = document.createElement("p");
        txt.setAttribute("class", "text");
        txt.innerText = "this note is a picture, once viewed, it will be deleted." 
        warning.appendChild(txt);
        
        //continue button
        let continue_btn = document.createElement("div");
        continue_btn.setAttribute("class", "continue");
        continue_btn.onclick = () => view_img(note_info, file_elm);
        continue_btn.innerText = "continue";
        warning.appendChild(continue_btn);
        
        file_elm.appendChild(warning_container);
      } else file_page(note_info, file_elm);
    }
  }
})(); 
  
//switches to new_note page
function new_from_view() {
  let url = `${window.location.origin}/new`;
  window.location.replace(url);
}

//switches to view_note page when "remove now" button pressed 
function view_from_new(elm) {
  //get the id from the element
  let id = elm.getAttribute("note_id");
  //replace the page with the view_note page for the current id
  let url = `${window.location.origin}/view?id=${id}`;
  window.location.replace(url);
}

async function copy_to_clipboard(txt) {
  try { //copy to clipboard
    await navigator.clipboard.writeText(txt);
  } catch (e) { alert(`couldn't copy to clipboard: ${e}`); }
}

//copy the note's url to clipboard when id element is clicked 
async function copy_id(elm) {
  //save the current class
  let old_class = elm.getAttribute("class");
  
  //add 'clipboard_copy' to the id element class for new styling
  elm.setAttribute("class", `${old_class}, clipboard_copy`);
  let id = elm.innerText; //get the id
  
  copy_to_clipboard(id);

  //wait 100ms then revert to the old styling by switching class back
  setTimeout(() => {
    elm.setAttribute("class", old_class);
  }, 100);
}

//only executed on new_note page
async function newNote() {
  { //make sure tab menu is closed 
    const tab = document.querySelector('.tab[is_open="true"');
    if (tab !== null) {
      tab.parentElement.querySelector("&> .close").click();
    }
  }

  //api url 
  let url = `${window.location.origin}/api/new`;

  let note_txt = document.getElementById("note").value;
  var note_comment = "no comment given";
  
  //note content
  let n = (note_file === null) ? note_txt : (() => {
    note_comment = note_txt;
    return note_file.bytes;
  })();

  const req_headers = new Headers();
  //ask for errs in HTML
  req_headers.append("err-html", "true");
  if (note_file !== null) {
    req_headers.append("comment", JSON.stringify(note_comment));
    req_headers.append("is-file", note_file.name);
  } if (server_info.use_encryption) req_headers.append("encrypt", "true");

  
  //make a POST request to server
  let resp = await (async () => {
    var r ; try {
      r = await fetch(url, {
        method: 'POST',
        headers: req_headers,
        body: n //use note as body
      });
    } catch (e) {
      //alert user
      if (e.request) {
        alert(`server didn't appear to respond:\n${e.request}`);
        return null; //don't don't go any further
      } else if (!e.response) {
        //alert user
        alert(`couldn't setup request: ${e.message}`); 
        return null; //don't go any further
      }
    }
    if (!r.ok) {
      //the response will contain an HTML err page
      const bod = await r.text();

      //replace the entire DOM with the err HTML page
      document.open("text/html", "replace");
      document.write(bod); //still 100% supported, and perfectly suits this use-case
      document.close();

      //throw err once done
      throw new Error(`err, stat: ${r.status}`);
    }
    return r;
  })();
  //don't attempt to do anything else
  if (resp === null) return;

  //get the id
  let id = await resp.text();

  //get the id element
  let idElm = document.querySelector(".note_page_btn");

  //change the id for the '#id' css attributes 
  idElm.setAttribute("id", "id");

  //put the id in the element
  idElm.innerText = `${window.location.origin}/view?id=${id}`;

  //change the class so css treats it as a different element
  idElm.setAttribute("class", "id");

  //make it copy to clipboard instead of executing this fn again 
  idElm.onclick = () => { return copy_id(idElm) };

  //remove the note '<textarea>' element
  document.getElementById("note").remove();

  //unhide all the id view elements
  let resView = document.querySelectorAll(".resText");
  for (var i = 0; i < resView.length; i++) {
    //alias for the '<button>'
    const btn = resView[i].querySelector("button")

    //only attempt to modify '<button>' if it exists
    if (btn != null) { btn.setAttribute("note_id", id); }

    //unhide element
    resView[i].removeAttribute("hidden");
  }

  const tab = document.querySelector("body > div > .tab");
  tab.setAttribute("class", "tab");
  tab.setAttribute("is_open", "false");
  tab.setAttribute("which", "res_text");
}

//download a file from a note
function dl_file(caller) {
  const link = (note_info.class == "Picture") ? (() => {
    const img = document.querySelector(".preview");

    const can = document.createElement("canvas");
    can.width = img.naturalWidth;
    can.height = img.naturalHeight;

    const ctx = can.getContext("2d");
    ctx.drawImage(img, 0, 0);

    return can.toDataURL();
  })() : `${window.location.origin}/api/view?id=${note_info.note_id}`;
  //the stupid "dance" (as they say) that must be done
  //  to download a file programmatically in JS
  const elm = document.createElement("a");
  elm.href = link;
  elm.setAttribute("download", note_info.file_name);
  elm.style.display = "none";
  document.body.appendChild(elm);
  elm.click();
  document.body.removeChild(elm);

  //let user know that it's now deleted
  const fi_elm = document.getElementById("file");
  const p = document.createElement("p");
  const i = document.createElement("i");
  i.innerText = "note deleted";
  p.appendChild(i);
  fi_elm.before(p);

  //disable the download button
  caller.setAttribute("disabled", "");
}

function view_img(note_info, file_elm) {
  let img_url = `${window.location.origin}/api/view?id=${note_info.note_id}`;
  file_elm.innerHTML = '';
  file_page(note_info, file_elm, img_url);
}

function file_page(note_info, file_elm, img) {
  //left pane
  var left = document.createElement("div");
  left.setAttribute("class", "left_pane");
  {
    //download button
    var dl_btn = document.createElement("button");
    dl_btn.onclick = () => { return dl_file(dl_btn) };
    dl_btn.setAttribute("class", "dl_btn");
    dl_btn.innerText = "download";
    left.appendChild(dl_btn);

    //local helper to create an element containing note attributes
    const new_attr = (classname, text, content_class, content) => {
      //note file size element
      var cont = document.createElement("p");
      cont.setAttribute("class", classname);
      cont.innerText = `${text}: `;
      //nest value in '<code>' element 
      var val = document.createElement("code");
      val.innerText = content;
      if (content_class !== null) val.className = content_class;
      cont.appendChild(val);
      left.appendChild(cont);
    };

    new_attr("fi_size", "file size", null, `${note_info.note_size} bytes`);
    new_attr("fi_typ", "file type", "file_type", note_info.file_type);
    new_attr("file_name", "filename", "name", note_info.file_name);
    
    if (note_info.comment != null) {
      let comment_title = document.createElement("p");
      comment_title.setAttribute("class", "comment_title");
      comment_title.innerText = "note comment";
      left.appendChild(comment_title);

      let comment = document.createElement("pre");
      comment.setAttribute("class", "note_comment");
      comment.innerText = note_info.comment;
      left.appendChild(comment);
    }
  }

  //right pane
  var right = document.createElement("div");
  right.setAttribute("class", "right_pane");
  {
    let is_img = note_info.class == "Picture";

    //preview pane title
    var preview_title = document.createElement("h3");
    preview_title.innerText = "preview";
    right.appendChild(preview_title);

    //file preview
    let pre_elm_type = (is_img) ? "img" : "pre";
    var preview_elm = document.createElement(pre_elm_type);
    preview_elm.setAttribute("class", "preview " + ((is_img) ? "img" : ""));
    if (is_img) preview_elm.src = img; else {
      const p_R = note_info.prev;
      preview_elm.innerText = (p_R == null) ? "couldn't generate preview" : p_R;
    }
      
    right.appendChild(preview_elm);
  }

  //add the panes to the document
  file_elm.appendChild(left);
  file_elm.appendChild(right);
}

function tab_btn(btn) {
  //lambda in a lambda in a lambda in a lambda
  const close_fn =  async () => {
    //for timing purposes, this has to be run after returning
    //  when the event is pressed 
    (async () => {
      setTimeout(() => { //set the onclick event back to what it was 
          btn.onclick = () => { return tab_btn(btn) };
      }, 100); //100ms
    })();
    return tab_btn(btn);
  }
  let is_open = JSON.parse(btn.getAttribute("is_open") || "false");
  btn.setAttribute("is_open", !is_open);
  let which = btn.getAttribute("which");
  btn.innerHtml = "";
  btn.innerText = "";
  if (is_open) {
    let close_btn = document.querySelector("div:has(.tab) > .close");
    if (close_btn !== null) close_btn.remove();
  }
  if (is_open) { btn.innerText = "\u2630" } else {
    switch (which) {
     case "new_note": {
        let container = document.createElement("div");
        container.className = "container";

        let close_btn = document.createElement("button");
        close_btn.className = "collapsed_close";
        btn.before(close_btn);
        (async () => {
          setTimeout(() => {
            close_btn.className = "close";
            close_btn.onclick = close_fn;
            close_btn.innerText = "\u2716";
            close_btn.removeAttribute("style");
          }, 1);
        })();

        let title = document.createElement("p");
        title.innerText = "upload file";
        container.appendChild(title);

        let input = document.createElement("input");
        input.setAttribute("type", "file");
        input.id = "file_input";
        input.addEventListener("change", file_input);
        container.appendChild(input);

        let clear_btn = document.createElement("button");
        clear_btn.className = "clear_file";
        clear_btn.onclick = () => {
          input.value = '';
        };
        clear_btn.innerText = "remove file";
        container.appendChild(clear_btn);

        //encryption toggle slider and label
        let encrypt_container = document.createElement("div");
        encrypt_container.className = "encrypt_cont";
        encrypt_container.setAttribute("enabled", server_info.use_encryption);
        encrypt_container.addEventListener("click", () => {
          let current = JSON.parse(encrypt_container.getAttribute("enabled"));
          encrypt_container.setAttribute("enabled", !current);
          console.log(!current);
        });
        let encrypt_switch = document.createElement("label");
        encrypt_switch.className = "switch";
        let encrypt_chk_box = document.createElement("input");
        encrypt_chk_box.setAttribute("type", "checkbox");
        encrypt_chk_box.checked = server_info.use_encryption;
        encrypt_switch.appendChild(encrypt_chk_box);
        let encrypt_slider = document.createElement("span");
        encrypt_slider.className = "slider";
        encrypt_switch.appendChild(encrypt_slider);
        encrypt_container.appendChild(encrypt_switch);
        {let childs = encrypt_switch.children;
          for (let i = 0; i < childs.length; i++)
            childs[i].addEventListener("click", (e) => e.stopPropagation());
        }
        container.appendChild(encrypt_container);
        
        btn.appendChild(container);

        //remove onclick so clicking background of element doesn't close it 
        btn.onclick = null;
      } break;
     case "res_text": {
      let close_btn = document.createElement("button");
      close_btn.setAttribute("class", "close");

      //lambda in a lambda in a lambda in a lambda
      close_btn.onclick = close_fn;
      close_btn.innerText = "\u2794";
      btn.appendChild(close_btn);

      let id_btn = document.createElement("button");
      id_btn.setAttribute("class", "copy_id");
      id_btn.onclick = async () => {
        id_btn.setAttribute("click", "");
        let url = new URL(document.getElementById("id").innerText);
        copy_to_clipboard(url.searchParams.get("id"));
        setTimeout(() => id_btn.removeAttribute("click"), 100);
      };
      id_btn.innerText = "copy id";
      btn.appendChild(id_btn);

      //remove onclick so clicking background of element doesn't close it 
      btn.onclick = null;
     } break;
     default:
      console.debug(`forgot ${which} in tab switch case`);
    }
  }
}

function file_input(event) {
  const file = event.target.files[0];
  if (file) {
    const re = new FileReader();
    re.onload = (ev) => {
      const arr_buf = ev.target.result;
      const bytes = new Uint8Array(arr_buf);
      note_file = { bytes:bytes, type:file.type, name:file.name };
    };
    re.onerror = (e) => {
      alert(`failed to read file: ${e}`);
      console.error("file reader error: ", e);
      return
    }
    re.readAsArrayBuffer(file);
  } else {
    alert("no file selected\nTODO:change alert to something not annoying");
  }
}
