"use strict";

(async function() {
  document.getElementById("js_warn").remove();
})(); 

async function newNote() {
  let url = `${window.location.origin}/api/new`;
  let n = document.getElementById("note").value;
  let resp = await fetch(url, {
    method: 'POST',
    headers: {
      'err-html': 'true',
    },
    body: n
  });
  if (!resp.ok) {
    const bod = await resp.text();
    document.open("text/html", "replace");
    document.write(bod); //still 100% supported, and perfectly suits this use-case
    document.close();
    throw new Error(`err, stat: ${resp.status}\n`);
  }
  let id = await resp.text();
  console.log(id)
  let idElm = document.querySelector(".note_page_btn");
  idElm.setAttribute("id", "id");
  idElm.innerText = `${id}`;
  idElm.setAttribute("class", "id");
  idElm.setAttribute("onclick", "copy_id(this);");
  document.getElementById("note").remove();
  let resView = document.querySelectorAll(".resText");
  for (var i = 0; i < resView.length; i++) {
    const btn = resView[i].querySelector("button")
    if (btn != null) { btn.setAttribute("note_id", id); }
    resView[i].removeAttribute("hidden");
  }
}

function view_from_new(elm) {
  let id = elm.getAttribute("note_id");
  let url = `${window.location.origin}/view?id=${id}`;
  window.location.replace(url);
}

function new_from_view() {
  let url = `${window.location.origin}/new`;
  window.location.replace(url);
}

async function copy_id(elm) {
  let old_class = elm.getAttribute("class");
  elm.setAttribute("class", `${old_class}, clipboard_copy`);
  let id = elm.innerText;
  try {
    await navigator.clipboard.writeText(id);
  } catch (e) { alert(`couldn't copy to clipboard\n\t${e}`); }
  setTimeout(() => {
    elm.setAttribute("class", old_class);
  }, 100);
}
