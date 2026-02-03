"use strict";

import { mkdir } from "node:fs/promises";
export {}; 

class fi {
  content:string;
  path:string;
  constructor(path:string) {
    this.path = path;
    const fi = Bun.file(path);
    this.content = await fi.text();
  }
};

const read_fi = (path:string) => {
  const c = new fi(path);
  return c.content;
};

const new_note = new fi("src/web/new_note.html");
const script:string = read_fi("src/web/script.js");
const css:string = read_fi("src/web/style.css");

const re_wr = new HTMLRewriter();

for (const thing of [ "*", "head" ]) re_wr.on(thing, {
  comments(comment) {
    const txt:string = comment.text.trim();
    ca: switch (txt) {
     case "style.css":
      comment.remove();
      comment.replace(`<style>${css}</style>`, { html:true });
      break;
     case "script.js":
      comment.remove();
      comment.replace(`<script async>${script}</script>`, { html:true });
      break;
     default:
      console.log(`skipping comment: ${JSON.stringify(txt)}`);
    }
  }
})

for (const page of [ new_note ]) {
  const out = re_wr.transform(page.content);
  const name = page.path.split("/");
  console.log(name);
}
