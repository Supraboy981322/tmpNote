"use strict";

import { minify as minify_html } from "html-minifier-terser";
import { transform as transform_css  } from "lightningcss";
import { Buffer } from "buffer";
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
};

const err_out = (msg:string) => { 
  console.error(msg);
  process.exit(1);
}
 
const minify_css = async (path:string) => {
  //read css
  const css_R = await Fi.read(path);

  //minify css
  let { code } = transform_css({
    filename: "stupid parser needs a file",
    code: Buffer.from(css_R.content),
    minify:true,
  });

  return `<style>${ code.toString() }</style>`; //return as element string
};

const minify_js = async (path:string) => {
  //minify js
  const b = await Bun.build({
    entrypoints: [path],
    minify: true,
    target: "browser",
  });

  //kill on error
  if (!b.success) err_out(`failed to minify js for web: ${b.logs}`);

  //return result (removing trailing newline because Bun inserts one for some reason)
  var res = await b.outputs[0].text();
  return `<script async>${ res.trim() }</script>`; //return as element string
};

//fucking shitty ass language. Can't even wait for an async fn syncronously
let web = {
  css: await minify_css("src/web/style.css"),
  js: await minify_js("src/web/script.js"),
  err_js: await minify_js("src/web/err.js"),
  err_css: await minify_css("src/web/err.css"),
};

//insert css and js into the document
const re_wr = new HTMLRewriter() ; var style_done:boolean = false; 
for (const thing of [ "*", "head", "title" ]) re_wr.on(thing, {
  //comments are used as placeholders
  comments(c) {
    //comment content
    const txt:string = c.text.trim();

    //local helper to replace comment with html
    const replac = async (s:string) => {
      ok = !0; c.remove(); c.replace(s, { html:true });
    }

    //for checks
    var ok:boolean = false;

    //switch on comment text
    switch (txt) {
     case "style.css": if (style_done)break; //Bun hallucinates a duplicate comment
      style_done = !0; replac(web.css);     break; //inject css
     case "script.js": replac(web.js);      break; //inject js
     case "err.css":   if (style_done)break; //Bun hallucinates a duplicate comment
      style_done = !0; replac(web.err_css); break; //inject err js
     case "err.js":    replac(web.err_js);  break; //inject err css
     //log any other comments
     default:
      console.log(`\t\t\x1b[35mskipping comment:\x1b[0m ${ JSON.stringify(txt) }`);
    }

    //if replaced, log replacement 
    if (ok) console.log(`\t\t\x1b[36mreplaced:\x1b[0m ${ JSON.stringify(txt) }`);
  }
})

for (const page of [ //array of web ui pages
  await Fi.read("./src/web/view_note.html"),
  await Fi.read("./src/web/new_note.html"),
  await Fi.read("./src/web/err.html"),
]) {
  //log current filepath
  console.log(`\t\x1b[33mminifying:\x1b[0m ${ JSON.stringify(page.path) }`);

  //path of final html file
  const filename = page.path.split("/").pop();
  const p = `./src/web_comp/${filename}`;

  //log output file
  console.log(`\t\x1b[34moutput:\x1b[0m    ${ JSON.stringify(p) }`);

  //reset style check
  style_done = false;

  //minify the html
  const html = await minify_html(page.content, {
    removeComments:false, //preserve comments
    caseSensitive:true,
    collapseWhitespace:true,
  });

  //inject CSS and JS into html placeholders
  const out = re_wr.transform(html);

  //write file to disk 
  await Bun.write(p, out);
}
