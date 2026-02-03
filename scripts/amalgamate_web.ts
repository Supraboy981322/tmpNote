"use strict";

import { mkdir } from "node:fs/promises";
const { minify } = require("html-minifier-terser");
export {}; 

class Fi {
  content:string;
  path:string;
  private constructor(content:string, path:string) {
    this.path = path;
    this.content = content;
  }
  static async read(path:string) {
    const fi = Bun.file(path);
    const content = await fi.text();
    return new Fi(content, path);
  }
  static async get_content(path:string) {
    const fi = await this.read(path);
    return fi.content;
  }
};

const new_note = await Fi.read("src/web/new_note.html");
const script:string = await Fi.get_content("src/web/script.js");
const css:string = await Fi.get_content("src/web/style.css");

const re_wr = new HTMLRewriter();

for (const thing of [ "*", "head", "title" ]) re_wr.on(thing, {
  comments(comment) {
    const txt:string = comment.text.trim();
    switch (txt) {
     case "style.css":
      // BUG: duplicate '<style>' element 
 //     comment.remove();
//      comment.replace(`<style>${css}</style>`, { html:true });
      break;
     case "script.js":
      comment.remove();
      comment.replace(`<script async>${script}</script>`, { html:true });
      break;
     case "server name":
      comment.remove();
      comment.replace("<server-name hidden></server-name>", { html:true });
      break;
     default:
      console.log(`skipping comment: ${JSON.stringify(txt)}`);
    }
  }
})

for (const page of [ new_note ]) {
  const html = await minify(page.content, {
    removeComments:false,
    caseSensitive:true,
    collapseWhitespace:true,
  });
  console.log(html);
  const out = re_wr.transform(html);
  let name_ = page.path.split("/");
  const name = name_[name_.length-1];
  const p = `./src/web_comp/${name}`;
  await Bun.write(p, out); 
  console.log(p);
}
