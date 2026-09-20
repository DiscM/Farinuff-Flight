# Third-party notices

Farinuff Flight includes or references the following third-party material. The original license files remain beside the source assets; this register is the release checklist for the compilation build.

| Material | Source / author | License or permission | Runtime use | Shipping action |
| --- | --- | --- | --- | --- |
| Barlow and Barlow Condensed | The Barlow Project Authors — [upstream](https://github.com/jpt/barlow); pinned sources and hashes in [`assets/fonts/barlow/manifest.json`](assets/fonts/barlow/manifest.json) | SIL Open Font License 1.1; unmodified font files, full text in [`assets/fonts/barlow/OFL.txt`](assets/fonts/barlow/OFL.txt) | Retained earlier typography assets | Include the copyright and OFL text with every package; export tooling copies it into `licenses/Barlow-OFL.txt`. |
| Oxanium | The Oxanium Project Authors / Severin Meyer — [upstream](https://github.com/sevmeyer/oxanium); pinned source and hashes in [`assets/fonts/oxanium/manifest.json`](assets/fonts/oxanium/manifest.json) | SIL Open Font License 1.1; unmodified font, full text in [`assets/fonts/oxanium/OFL.txt`](assets/fonts/oxanium/OFL.txt) | Angular headings and action buttons, SemiBold weight | Include the copyright and OFL text; export tooling copies it into `licenses/Oxanium-OFL.txt`. |
| IBM Plex Sans | IBM Corp. — [upstream](https://github.com/IBM/plex); pinned sources and hashes in [`assets/fonts/ibm-plex-sans/manifest.json`](assets/fonts/ibm-plex-sans/manifest.json) | SIL Open Font License 1.1; unmodified fonts, full text in [`assets/fonts/ibm-plex-sans/OFL.txt`](assets/fonts/ibm-plex-sans/OFL.txt) | Body text, HUD data, emphasis and narrative italics | Include the copyright and OFL text; export tooling copies it into `licenses/IBM-Plex-Sans-OFL.txt`. |
| PixelPlanets shaders and scenes | Deep-Fold — [`effects/shaders/PixelPlanets/README.md`](effects/shaders/PixelPlanets/README.md) | MIT; full text in [`effects/shaders/PixelPlanets/LICENSE`](effects/shaders/PixelPlanets/LICENSE) | Menu planets, background planets, and the boss black hole | Ship the MIT notice with the final package. |
| Kenney UI pack | Kenney — [`ui/kenney_ui-pack-space-expansion/License.txt`](ui/kenney_ui-pack-space-expansion/License.txt) | CC0; attribution is optional | Retained UI pack source | Keep the license file if any pack asset ships. |
| Game UI collection | SunGraphica — [`assets/Game UI collection FREE version/Sungraphica + info .txt`](assets/Game%20UI%20collection%20FREE%20version/Sungraphica%20%2B%20info%20.txt) | The repository contains source information but not a machine-readable license grant | Pause-menu textures | Confirm commercial redistribution terms and required attribution before release. |
| Shapeforms audio samplers | Shapeforms Audio — [`assets/Shapeforms Audio Free Sound Effects/`](assets/Shapeforms%20Audio%20Free%20Sound%20Effects/) | The retained sampler notes permit commercial use for the Future UI sampler; the complete agreement is [`Shapeforms Audio License Agreement.pdf`](assets/Shapeforms%20Audio%20Free%20Sound%20Effects/Shapeforms%20Audio%20License%20Agreement.pdf) | Hit, pickup, boost, UI, and ambient audio | Confirm each selected preview pack against the agreement and ship any required notice. |

## Release checklist

- [ ] Reconfirm the SunGraphica permission and attribution requirements for the exact pause-menu textures.
- [ ] Reconfirm the Shapeforms agreement covers every selected audio preview in the shipping build.
- [ ] Include this register and the applicable full license texts in the release archive or credits screen.
- [ ] Re-run the artifact inspection after export so editor-only source packs and raw previews are not distributed accidentally.
