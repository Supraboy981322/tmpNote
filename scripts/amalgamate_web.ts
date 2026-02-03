"use strict";

export {};

const script:string = await (async ():Promise<string> => {
  const fi = Bun.file("src/web/script.js");
  return await fi.text();
})();

const css:string = await (async ():Promise<string> => {
  const fi = Bun.file("src/web/style.css");
  return await fi.text();
})();

const cont:string = await (async () => {
  const fi = Bun.file("src/web/new_note.html");
  return await fi.text();
})();

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

const out = re_wr.transform(cont);
console.log(out); 
