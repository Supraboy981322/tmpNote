window.onload = async () => {
  var p = window.location.href.split("//")[1];
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
