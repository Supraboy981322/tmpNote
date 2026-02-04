window.onload = async () => {
  const p = window.location.href;
  document.querySelector(".reqPage").innerText = p;
  const err_info = document.getElementById("err_info");
  const err_json = JSON.parse(err_info.innerText);
  const code = err_json.code;
  switch (+code) {
    case 400 | 404:
      var btn = document.createElement("button");
      btn.setAttribute("id", "new_note_btn");
      btn.onclick = new_note;
      btn.setAttribute("class", "tiny");
      btn.innerText = "new note";
      btn.setAttribute("hidden", "");
      document.querySelector(".reqPage").after(btn);
      (async () => {
        setTimeout(() => {
          btn.removeAttribute("hidden");
        }, 999);
      })();
      setTimeout(() => {
        btn.removeAttribute("class");
      }, 1000);
      break;
  } 
};

function new_note() {
  const o = window.location.origin;
  window.location.assign(`${o}/new`);
} 
