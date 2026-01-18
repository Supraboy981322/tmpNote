"use strict";

var note_info = undefined;

//remove "enable JavaScript" warning
(async function() {
  document.getElementById("js_warn").remove();
  const note_info_elm = document.getElementById("note_info");
  if (note_info_elm != null) {
    note_info = JSON.parse(note_info_elm.innerText);
    if (note_info.is_file) {
      console.log("is a file");
      const file_elm = document.getElementById("file");

      var left = document.createElement("div");
      left.setAttribute("class", "left_pane");
      {
        var dl_btn = document.createElement("button");
        dl_btn.onclick = "dl_file();";
        dl_btn.setAttribute("class", "dl_btn");
        dl_btn.innerText = "download";
        left.appendChild(dl_btn);

        var fi_size = document.createElement("p");
        fi_size.setAttribute("class", "fi_size");
        fi_size.innerText = `note size: ${note_info.note_size} bytes`;
        left.appendChild(fi_size);
        
        var fi_typ = document.createElement("p");
        fi_typ.setAttribute("class", "fi_typ");
        fi_typ.innerText = `file type: `;
        var file_type_elm = document.createElement("code");
        file_type_elm.setAttribute("class", "file_type");
        file_type_elm.innerText = note_info.file_type;
        fi_typ.appendChild(file_type_elm);
        left.appendChild(fi_typ);
      }
      var right = document.createElement("div");
      right.setAttribute("class", "right_pane");
      {
        var preview_title = document.createElement("h3");
        preview_title.innerText = "preview";
        right.appendChild(preview_title);

        var preview_text = document.createElement("pre");
        preview_text.setAttribute("class", "preview");
        const p_R = note_info.prev;
        preview_text.innerText = (p_R == null) ? "couldn't generate preview" : p_R;
        right.appendChild(preview_text);
      }

      file_elm.appendChild(left);
      file_elm.appendChild(right);
    } else { console.log("not a file"); }
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
  } catch (e) { alert(`couldn't copy to clipboard\n\t${e}`); }
  //wait 100ms then revert to the old styling by switching back class
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
    //ask for errs in HTML 
    headers: {
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
    throw new Error(`err, stat: ${resp.status}\n`);
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
  idElm.setAttribute("onclick", "copy_id(this);");
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
