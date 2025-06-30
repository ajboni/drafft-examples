# drafft-examples

Small sample projects and utilities for [Drafft](https://drafft.dev).

## Projects

### The goddess of fate

Writer: boghdanwrites.  
Adaptation to App: Alexis Boni.  
Description: A visual novel about the zodiac.

### One Bullet

> Rumor says, it is a bullet capable of erasing someone's existence.

Writer: Sara Santos  
Adaptation to App: Alexis Boni  
Description: A Mockup for a point and click game about a heist. Its not as complete as the goddess of fate.

### How to import them in the app?

v1: Go to Project Manager => Restore backup in new project.
v2: Go to project Manager => Download sample project.

## Utilities

- `migrate-to-v2.js`: A script to migrate a v1 project to v2. It will try to also update the json files from v1 to the new schema in v2. It will be best effort and images will be ignored. run it with `node migrate-to-v2.js <path-to-v1-project> <path-to-v2-project>`.

- `Drafft Downloader Script`: Auto Download latest version and Fix potential Appimage sandbox permission issues and create a desktop entry. Built by Wade Schneider @ Nano Game Lab -> https://github.com/The-Maize . For the use strictly with Drafft 2 .

## Contributing

Contributions are welcome! To share a sample project do a Database Backup and commit the json file.

## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
