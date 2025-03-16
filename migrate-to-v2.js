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

  /* Dialogue folder was previously created with only child ids, now we are using objects as subfolders 
  This will probably have other implications for missing fields. TODO: check if we need to add more fields */

  const folders = data.rows.filter((row) => row.doc?.type === "Folder");

  for (const folder of folders) {
    const { doc } = folder;
    console.log(doc);
    if (doc.children?.length > 0) {
      const newChildren = [];
      for (const child of doc.children) {
        newChildren.push({ _id: child });
      }
      doc.children = newChildren;
    }
  }

  /* Dialog schema has changed as well to adapt to the new content: strategy and also reactflow */
  const dialogues = data.rows.filter((row) => row.doc?.type === "Dialogue");
  for (const dialogue of dialogues) {
    const { doc } = dialogue;
    const g = doc.graph;
    doc.content = {
      tree: {
        nodes: g.nodes.map((node) => ({
          id: node.id,
          position: { x: node.x * 2, y: node.y * 2 },
          sourcePosition: "left",
          targetPosition: "right",
          type: "base",
          dragHandle: ".drag-handle__header",
          // type: node.extras.type.toLowerCase(),
          data: {
            label: node.name,
            handles: node.ports.map((port) => ({
              id: port.id,
              type: port.in ? "target" : "source",
              label: port.label,
            })),
            nodeType: node.extras.type.toLowerCase(),
            scriptId: node.extras.scriptID,
          },
        })),
        edges: g.links.map((link) => ({
          edgeId: link.id,
          id: link.id,
          key: link.id,
          source: link.source,
          target: link.target,
          sourceHandle: link.sourcePort,
          targetHandle: link.targetPort,
          animated: false,
        })),
      },
    };
  }

  /* Grid items also use content to align with the new tab strategy */
  const grids = data.rows.filter((row) => row.doc?.type === "Grid");
  for (const grid of grids) {
    const { doc } = grid;
    doc.content = {
      columns: doc.columns,
      data: doc.data,
    };
  }

  /* We no longer have the hotkeys collection */
  data.rows = data.rows.filter((x) => x.doc.collection !== "Hotkeys");
  return data;
}
