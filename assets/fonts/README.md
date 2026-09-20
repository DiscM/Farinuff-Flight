# Interface typography

- **Oxanium SemiBold (600):** titles, section headings, and action buttons. Configured by `ui/themes/cabinet_heading.tres`.
- **IBM Plex Sans Regular (400):** default interface copy, descriptions, and instructions. Configured by `ui/themes/interface_body.tres`.
- **IBM Plex Sans SemiBold (600):** HUD counters, status text, and bold passages. `interface_emphasis.tres` enables tabular numerals so changing counters keep their width.
- **IBM Plex Sans Italic / SemiBold Italic:** rich-text narrative passages through the matching interface resources.

The project theme and `NeonUI` share these resources. Font sizes and the existing menu/HUD accessibility scaling remain independent of the selected font family. The numeric OpenType keys in the resources encode `wght` (2003265652), `wdth` (2003072104), and `tnum` (1953396077), as required by the shipped Godot 4.6 renderer.

Fonts are bundled locally and need no network connection at runtime. The binary files are unmodified; each family directory contains the complete SIL Open Font License and a manifest with its pinned Google Fonts source revision and SHA-256 hashes. Release presets include both licenses, and the export tool also copies them into the package's `licenses/` folder.

The earlier Barlow files are retained with their original notice for historical assets; active game UI uses the families above.
