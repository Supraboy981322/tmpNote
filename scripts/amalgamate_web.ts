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
 
//minified css file
const css:string = await (async () => {
  //read css
  const css_R = await Fi.read("src/web/style.css");
  //minify css
  let { code } = transform_css({
    filename: "stupid parser needs a file",
    code: Buffer.from(css_R.content),
    minify:true,
  });
  return code.toString(); //get result
})();

const script:string = await (async () => {
  //minify js
  const b = await Bun.build({
    entrypoints: ["src/web/script.js"],
    minify: true,
    target: "browser",
  });
  //kill on error
  if (!b.success) {
    console.error(`failed to minify js for web: ${b.logs}`);
    process.exit(1);
  }
  //return result (removing trailing newline because Bun inserts one for some reason)
  var res = await b.outputs[0].text();
  return res.trim();
})();

//insert css and js into the document
const re_wr = new HTMLRewriter() ; var style_done:boolean = false; 
for (const thing of [ "*", "head", "title" ]) re_wr.on(thing, {
  //comments are used as placeholders
  comments(comment) {
    //comment content
    const txt:string = comment.text.trim();
    //for checks
    var ok:boolean, new_plac:boolean;
    ok = new_plac = false;

    switch (txt) {
     //inject CSS
     case "style.css":if (style_done) break; //Bun hallucinates a duplicate comment
      ok = true;style_done = true;
      comment.remove();
      comment.replace(`<style>${css}</style>`, { html:true });
      break;
     //inject JS
     case "script.js": ok = true;
      comment.remove();
      comment.replace(`<script async>${script}</script>`, { html:true });
      break;
     default: //log anything that doesn't match 
      console.log(`\t\t\x1b[35mskipping comment:\x1b[0m ${JSON.stringify(txt)}`);
    }

    //if replaced, log replacement 
    if (ok) console.log(`\t\t\x1b[36m${
        (new_plac) ? "temporary_replacement" : "replaced"
      }:\x1b[0m ${ JSON.stringify(txt) }`);
  }
})

//log that it's starting
console.log("[\x1b[34mbuilding web ui...\x1b[0m]");

for (const page of [ //array of web ui html
  await Fi.read("src/web/view_note.html"),
  await Fi.read("src/web/new_note.html"),
]) {
  //log current filepath
  console.log(`\t\x1b[33mminifying:\x1b[0m ${ JSON.stringify(page.path) }`);
  //reset style check
  style_done = false;

  //minify the html
  const html = await minify_html(page.content, {
    removeComments:false,
    caseSensitive:true,
    collapseWhitespace:true,
  });

  //inject CSS and JS into html placeholders
  const out = re_wr.transform(html);

  //path of final html file
  const filename = page.path.split("/").pop();
  const p = `./src/web_comp/${filename}`;

  //write file to disk 
  await Bun.write(p, out);
}

//log completion
console.log("[\x1b[32mdone\x1b[0m]");
