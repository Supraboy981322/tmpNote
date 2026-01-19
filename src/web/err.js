window.onload = async () => {
  const p = window.location.hostname+window.location.pathname;
  document.querySelector(".reqPage").innerText = p;
  const code = document.getElementById("response_code").innerText;
  switch (+code) {
    case 400:
      var btn = document.createElement("button");
      btn.setAttribute("id", "new_note_btn");
      btn.setAttribute("onclick", "new_note()");
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
