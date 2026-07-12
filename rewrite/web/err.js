"use strict";

//setup page
window.onload = async () => {
  //get url
  const p = window.location.href;

  //display the url on the page 
  document.querySelector(".reqPage").innerText = p;

  //get the err stats
  const err_info = document.getElementById("err_info");
  const err_json = JSON.parse(err_info.innerText);

  //switch on err code
  switch (+err_json.code) {
    case 400 | 404: //user error
      //create a btn to mk a new note 
      var btn = document.createElement("button"); 
      btn.setAttribute("id", "new_note_btn");
      btn.setAttribute("class", "tiny");
      btn.innerText = "new note";
      btn.onclick = new_note;

      //append as hidden element
      btn.setAttribute("hidden", "");
      document.querySelector(".reqPage").after(btn);

      //some timing stuff so the button is un-hidden and fades in perfectly 
      //  (only tested on FireFox)
      (async () => setTimeout(btn.removeAttribute("hidden"), 999))();
      setTimeout(btn.removeAttribute("class"), 1000);

      break;
    // TODO: handle other error codes 
  }
};

//just moves user to new note page
function new_note() {
  const o = window.location.origin;
  window.location.assign(`${o}/new`);
} 
