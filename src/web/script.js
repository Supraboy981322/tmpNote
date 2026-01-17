async function newNote() {
  url = `${window.location.origin}/api_new`;
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
  let idElm = document.getElementById("id");
  idElm.innerText = id;
  idElm.setAttribute("class", "id");
  idElm.removeAttribute("onclick");
  document.getElementById("note").remove();
  let resView = document.querySelector(".resText");
  resView.querySelector("button").setAttribute("note_id", id);
  resView.removeAttribute("hidden");
}

function view_from_new(elm) {
  let id = elm.getAttribute("note_id");
  url = `${window.location.origin}/view?id=${id}`;
  window.location.replace(url);
}

function new_from_view() {
  url = `${window.location.origin}/new`;
  window.location.replace(url);
}
