"use strict";

//html
import { minify as minify_html } from "html-minifier-terser";
//import { lightningcss as minify_css } from '@node-minify/lightningcss';
export {}; //so I can use async stuff  

//file class
class Fi {
  content:string; //file content
  path:string;    //filepath
  //private so async can be used to create instance
  private constructor(content:string, path:string) {
    this.path = path;
    this.content = content;
  }
  //mtd to create a new file instance 
  static async read(path:string) {
    const fi = Bun.file(path);
    const content = await fi.text();
    return new Fi(content, path);
  }
  //mtd to get just the content 
  static async get_content(path:string) {
    const fi = await this.read(path);
    return fi.content;
  }
};
 
const new_note = await Fi.read("src/web/new_note.html");
const script:string = await Fi.get_content("src/web/script.js");
const css_R:string = await Fi.get_content("src/web/style.css");
//const minified_css = await minify_css({
//  
//});
//insert css and js into the document 
const re_wr = new HTMLRewriter();var style_done:boolean = false;
for (const thing of [ "*", "head", "title" ]) re_wr.on(thing, {
  comments(comment) { //comments are used as placeholders
    const txt:string = comment.text.trim();
    var ok:boolean = false;
    var new_plac:boolean = false;
    switch (txt) {
     case "style.css":if (style_done) break; //for some reason Bun hallucinates a duplicate comment
      ok = true;style_done = true;
      comment.remove();
      comment.replace(`<style>${css_R}</style>`, { html:true });
      break;
     case "script.js": ok = true;
      comment.remove();
      comment.replace(`<script async>${script}</script>`, { html:true });
      break;
     default: //log anything that doesn't match 
      console.log(`\t\t\x1b[35mskipping comment:\x1b[0m ${JSON.stringify(txt)}`);
    }
    if (ok) console.log(`\t\t\x1b[36m${(new_plac) ? "temporary_replacement" : "replaced"}:\x1b[0m ${JSON.stringify(txt)}`);
  }
})

console.log("[\x1b[34mstarting...\x1b[0m]");
for (const page of [ new_note ]) {
  console.log(`\t\x1b[33mminifying:\x1b[0m ${JSON.stringify(page.path)}`);
  const html = await minify_html(page.content, {
    removeComments:false,
    caseSensitive:true,
    collapseWhitespace:true,
  });
  const out = re_wr.transform(html);
  let name_ = page.path.split("/");
  const name = name_[name_.length-1];
  const p = `./src/web_comp/${name}`;
  await Bun.write(p, out); 
}
console.log("\x1b[32mdone\x1b[0m");
