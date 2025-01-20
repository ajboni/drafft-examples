const fs = require('fs');
var TurndownService = require('turndown')

var turndownService = new TurndownService()

// Load the input and output file paths from command line arguments
const inputFilePath = process.argv[2];
const outputFilePath = process.argv[3];

if (!inputFilePath || !outputFilePath) {
  console.error('Usage: node migrate-to-v2.js <inputFilePath> <outputFilePath>');
  process.exit(1);
}

fs.readFile(inputFilePath, 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading input file:', err);
    return;
  }

  let jsonData;
  try {
    jsonData = JSON.parse(data);
  } catch (parseErr) {
    console.error('Error parsing JSON:', parseErr);
    return;
  }

  // Apply transformation rules
  const transformedData = applyMigrations(jsonData);

  // Write the output JSON file
  fs.writeFile(outputFilePath, JSON.stringify(transformedData, null, 2), 'utf8', (writeErr) => {
    if (writeErr) {
      console.error('Error writing output file:', writeErr);
      return;
    }
    console.log('Output file written successfully');
  });
});

function applyMigrations(data) {
  
  const scripts = data.rows.filter(row => row.doc?.type === 'Script');
  
  /** Scripts: 
  * scriptEditorMode => editorMode 
  * */
  scripts.forEach(doc => {
    doc.editorMode= doc.scriptEditorMode;
  });
  
  /** Actors:  
   *  - bio, expressions and properties now live under "content" key;
   *  - bio is now markdown
   * */ 
  const actors = data.rows.filter(row => row.doc?.type === 'Actor');
  for(const actor of actors) {
    const {doc} = actor;
    doc.content = {
      bio:  turndownService.turndown(doc.bio) || '',
      expressions: [] || '',
      properties: doc.properties || ''
    }
    console.log(actor.doc.content);
  };

  return data;
}