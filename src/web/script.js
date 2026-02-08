"use strict";

//set later
var note_info = undefined; //may use for more than rendering the page 

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
  
  if (document.querySelector("body>div>h1>.page").innerText == "new") {
    //create tab element
    let tab = document.createElement("div");
    tab.setAttribute("class", "tab");
    tab.setAttribute("is_open", "false");
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

//copy the note's url to clipboard when id element is clicked 
async function copy_id(elm) {
  //save the current class
  let old_class = elm.getAttribute("class");
  
  //add 'clipboard_copy' to the id element class for new styling
  elm.setAttribute("class", `${old_class}, clipboard_copy`);
  let id = elm.innerText; //get the id

  try { //copy to clipboard
    await navigator.clipboard.writeText(id);
  } catch (e) { alert(`couldn't copy to clipboard: ${e}`); }

  //wait 100ms then revert to the old styling by switching class back
  setTimeout(() => {
    elm.setAttribute("class", old_class);
  }, 100);
}

//only executed on new_note page
async function newNote() {
  //api url 
  let url = `${window.location.origin}/api/new`;

  //note content
  let n = document.getElementById("note").value;
  
  //make a POST request to server
  let resp = await fetch(url, {
    method: 'POST',
    headers: {//ask for errs in HTML 
      'err-html': 'true',
    },
    body: n //use note as body
  });
  if (!resp.ok) {
    //the response will contain an HTML err page
    const bod = await resp.text();

    //replace the entire DOM with the err HTML page
    document.open("text/html", "replace");
    document.write(bod); //still 100% supported, and perfectly suits this use-case
    document.close();

    //throw err once done
    throw new Error(`err, stat: ${resp.status}`);
  }
  //get the id
  let id = await resp.text();

  //get the id element
  let idElm = document.querySelector(".note_page_btn");

  //change the id for the '#id' css attributes 
  idElm.setAttribute("id", "id");

  //put the id in the element
  idElm.innerText = `${id}`;

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
  elm.setAttribute("download", "TODO_download_with_filename");
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

    //note file size element
    var fi_size_cont = document.createElement("p");
    fi_size_cont.setAttribute("class", "fi_size");
    fi_size_cont.innerText = "note size:";
    //nest value in '<code>' element 
    var fi_size = document.createElement("code");
    fi_size.innerText = `${note_info.note_size} bytes`;
    fi_size_cont.appendChild(fi_size);
    left.appendChild(fi_size_cont);
    
    //note file type 
    var fi_typ = document.createElement("p");
    fi_typ.setAttribute("class", "fi_typ");
    fi_typ.innerText = "file type:";
    //nest value in '<code>' element 
    var file_type_elm = document.createElement("code");
    file_type_elm.setAttribute("class", "file_type");
    file_type_elm.innerText = note_info.file_type;
    fi_typ.appendChild(file_type_elm);
    left.appendChild(fi_typ);
    
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
  let is_open = JSON.parse(btn.getAttribute("is_open") || "false");
  btn.innerHtml = "";
  btn.setAttribute("is_open", !is_open);
  if (is_open) { btn.innerText = "\u2630" } else {
  }

}
