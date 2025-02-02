const fs = require("fs");
var TurndownService = require("turndown");

var turndownService = new TurndownService();

// Load the input and output file paths from command line arguments
const inputFilePath = process.argv[2];
const outputFilePath = process.argv[3];

if (!inputFilePath || !outputFilePath) {
  console.error("Usage: node migrate-to-v2.js <inputFilePath> <outputFilePath>");
  process.exit(1);
}

fs.readFile(inputFilePath, "utf8", (err, data) => {
  if (err) {
    console.error("Error reading input file:", err);
    return;
  }

  let jsonData;
  try {
    jsonData = JSON.parse(data);
  } catch (parseErr) {
    console.error("Error parsing JSON:", parseErr);
    return;
  }

  // Apply transformation rules
  const transformedData = applyMigrations(jsonData);

  // Write the output JSON file
  fs.writeFile(outputFilePath, JSON.stringify(transformedData, null, 2), "utf8", (writeErr) => {
    if (writeErr) {
      console.error("Error writing output file:", writeErr);
      return;
    }
    console.log("Output file written successfully");
  });
});

function applyMigrations(data) {
  /** GDD:
   * content now lives under content.gdd;
   * */
  const gdds = data.rows.filter((row) => row.doc?.type === "Gdd");
  for (const gdd of gdds) {
    const { doc } = gdd;
    if (doc.content.gdd === undefined) {
      doc.content = {
        gdd: doc.content,
      };
    }
  }

  /** Scripts:
   * scriptEditorMode => editorMode
   * */
  const scripts = data.rows.filter((row) => row.doc?.type === "Script");
  scripts.forEach((script) => {
    const { doc } = script;
    doc.editorMode = doc.scriptEditorMode;
    if (doc.content.script === undefined) {
      doc.content = {
        script: doc.content,
      };
    }
  });

  /** Actors:
   *  - bio, expressions and properties now live under "content" key;
   *  - bio is now markdown
   *  - _attachments are not stored with the document anymore. (used drafft://protocol instead)
   * */
  const actors = data.rows.filter((row) => row.doc?.type === "Actor");
  for (const actor of actors) {
    const { doc } = actor;
    if (!doc.content || doc.content.bio === undefined) {
      doc.content = {
        bio: turndownService.turndown(doc.bio) || "",
        expressions: [] || "",
        properties: doc.properties || "",
      };
      delete doc._attachments;
    }
  }

  /* We no longer have the hotkeys collection */
  data.rows = data.rows.filter((x) => x.doc.collection !== "Hotkeys");
  return data;
}
