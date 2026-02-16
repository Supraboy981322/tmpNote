"use strict";

export{};
import { readdir } from "node:fs/promises";

const files = await readdir("./include", { recursive: true });

const imports:string[] = [];
var c_comments = "";
var main = "";

for (let fi of files) {
  const ext = fi.split(".")[1];
  if (ext === undefined) continue; else if (ext === "go") {
    const path = fi.split("/");
    if (path.length === 1) continue;
    const f = Bun.file(`include/${fi}`);
    const src = await f.text()
    const lines = src.split(/\t?\n/);
    var in_imports = false;
    var in_c_comment = false;
    for (var line of lines) {
      line = line.trim();
      if (line.length == 0 || line.includes("main")) continue;
      const first_word = line.split(" ")[0]; 
      const second_word = line.split(" ")[1];
      if (first_word === "package") continue;
      switch (first_word) {
       case "/*": case "*/":
        in_c_comment = !in_c_comment; break;
       case "import":
        if (!second_word.includes(`"C"`)) in_imports = true; break;
       case ")": case ");":
        if (in_imports) { in_imports = false; break; }
       default:
        if (in_imports) {
          if (!imports.includes(line)) imports.push(line)
        } else if (in_c_comment)
          c_comments += line+"\n";
        else
          main += line+"\n";
      }
    }
  }
}

var final = `package main
/*
${c_comments}
*/
import ("C")
import (${
  (() => {
    var res = ""
    for (const imp of imports) res += imp+"\n";
    return res;
  })()
})
func main() {}
${main}
`;

try {
  await Bun.write("include/combined.go", final);
  console.log("wrote file");
} catch (e) {
  console.error(e);
  process.exit(1);
}
