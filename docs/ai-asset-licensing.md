# AI-Generated Asset Licensing (Gemini)

Status: **validated for use** (recorded 2026-11-22). This note answers the open question of whether Gemini-generated images and the vector art derived from them may ship in Gatekeeper's Ward and its hackathon submission.

## Conclusion

Yes. Google does not claim ownership of content generated with Gemini or the Gemini API. The team may use the generated artwork, and the vector conversions made from it, as app icons and UI art, provided the conditions below are met.

## What Google's terms say

Re-checked against the live pages on 2026-11-22.

| Claim | Source | Result |
|---|---|---|
| "Some of our services allow you to generate original content. Google won't claim ownership over that content." | [Google Terms of Service](https://policies.google.com/terms), "Content in Google services", effective July 30, 2026 | Confirmed, wording matches. |
| "Your content remains yours, which means that you retain any intellectual property rights that you have in your content." | Same page, "Permission to use your content" | Confirmed, wording matches. |
| "Some of our Services allow you to generate original content. Google won't claim ownership over that content. You acknowledge that Google may generate the same or similar content for others and that we reserve all rights to do so." | [Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms) (served at `aistudio.google.com/docs/terms`), "Use of Generated Content", effective March 23, 2026 | Confirmed, wording matches (page text supplied by iolaire on 2026-11-22, since the page cannot be fetched without JavaScript). |
| "…remember that you agreed to Google's Terms of Service, including the Prohibited Use Policy. Be sure not to violate others' copyright or privacy rights. Use your discretion before you rely on, publish, or use content that Gemini Apps generate." | [Generate & edit images with Gemini Apps](https://support.google.com/gemini/answer/14286560) | Confirmed. The page now describes the image models as Nano Banana. |
| Prohibition on "misleading others into thinking that generative AI content was created by a human" | Google Terms of Service, "Don't abuse our services" | Confirmed. The [Generative AI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy) (last modified December 17, 2024) adds: do not misrepresent provenance by claiming content was created solely by a human, in order to deceive. |

### Correction to the earlier analysis

The analysis said Google prohibits using generated content to train *competing* models. The Google Terms of Service are broader: they prohibit "using AI-generated content from our services to develop machine learning models or related AI technology". The separate Gemini API terms add the "compete with the Services" wording. Shipping the images as UI assets is not affected. Do not use them as training data for any model.

### Which terms apply

Per iolaire, the images were generated at gemini.google.com (the consumer Gemini app) in a notebook. That puts them under the **Google Terms of Service**, the **Generative AI Prohibited Use Policy** and the **Gemini Apps help page**, all verified above. The Gemini API Additional Terms cover Gemini API and AI Studio, are aimed at professional developers, and do not govern these images. They give the same ownership position, so the conclusion is unchanged.

Notebooks in the Gemini app are a Gemini Apps feature that syncs with NotebookLM, per Google's [Create and use notebooks in Gemini Apps](https://support.google.com/gemini/answer/16972047) help page. Google has also renamed NotebookLM to Gemini Notebook (notebook.google). Neither source mentions a separate ownership or image-rights term for notebooks. The Google ToS sentence "Some of our services allow you to generate original content. Google won't claim ownership over that content" applies to any Google service that generates content, so it covers notebook output. Under the Google ToS the team is responsible for not infringing others' rights in the output and for not presenting it as human-made. The README disclosure covers the second point.

A written answer from Google about notebooks (pasted by iolaire, 2026-11-22) reaches the same conclusion. It is not an official terms document and reads as an AI-generated reply, so it is not cited as authority. Two of its details are wrong for this project. It cites the "Generative AI Additional Terms of Service", which Google retired on May 22, 2024 (folded into the Google ToS). It also suggests MIT or CC0 for the art, but this repository uses Apache 2.0.

## Conditions we follow

1. **Disclose AI assistance.** Google's terms prohibit misleading others into thinking generative AI content was created by a human. Docs and the Devpost text must say the artwork was AI-assisted (Gemini) and must not call it hand-drawn. The README carries this disclosure.
2. **No third-party IP in outputs.** We are responsible for outputs that resemble protected characters, logos or trademarks. Review each generated image before it is used. The spirits are original characters.
3. **No model training.** Generated images may not be used to develop machine learning models or related AI technology. Using them as UI assets and icons is allowed.
4. **Uniqueness is not guaranteed.** Google may generate the same or similar content for others. Nothing in the project depends on the art being exclusive.

## Kiroween rules alignment

Kiroween sections 4 and 7 (Intellectual Property) require that submission materials do not violate third-party copyright and that the team has permission to use any third-party tools incorporated into the project. Because Google claims no ownership of the output, Gemini-generated artwork and its vector conversions meet the ownership and licensing criteria, subject to the conditions above.

## Mood-board JPGs (redistribution rights settled)

The four JPGs in `docs/Planning/Styles/` (`Darwin’s Beagle & The Specimen Cabinet`, `Kiroween Neon Gothic`, `Phosphor Morgue`, `The Castle Keep & The Wandering Spirits`) are Google-generated. Checked 2026-11-22 with `exiftool`: each file embeds a C2PA Content Credentials manifest signed by Google (claim generator "Google C2PA Core Generator Library", actions `c2pa.created`, digital source type `trainedAlgorithmicMedia`). They are not third-party stock or scraped images.

Because Google does not claim ownership of generated output and does not restrict sharing or distributing it, the JPGs may stay in the public repository. This is subject to the same conditions as above: disclose AI assistance, and keep third-party IP and trademarks out of them. Open-sourcing the art is also consistent with Kiroween's requirement that the repo contain the assets needed to evaluate the project.

Keep the embedded C2PA metadata. Do not strip or re-encode the files in a way that removes it, since it is the provenance record.

## Licence for the art

The art follows the repository licence, **Apache 2.0** (see `LICENSE` and `NOTICE`), the same as the code. We did not choose a separate asset licence such as CC0 or CC BY 4.0, because one licence keeps the repo simple and matches what GitHub detects. Where a generated image has no copyrightable human authorship, the licence grants nothing beyond what the law already allows, and that is acceptable here.

## Asset inventory

Provenance: the images were generated in this Gemini notebook, which needs a Google sign-in and may not be viewable by others: https://gemini.google.com/notebook/359c775f-b390-44fc-a784-1e6c2bd0f0de

Checked 2026-11-22 against the repo (`git ls-files`, `exiftool`, file contents). Per iolaire: all image assets, including all four SVG sprites, came from Gemini. Kiro wrote the Swift code that draws them.

| Asset | Origin | Evidence |
|---|---|---|
| `docs/Planning/Styles/*.jpg` (4 mood boards) | Google generative AI (Gemini) | Embedded Google C2PA manifest, `trainedAlgorithmicMedia`. |
| `docs/Planning/Styles/solo_spirit.svg`, `cloaked_spirit.svg`, `duo_spirits.svg`, `castle_gate_spirits.svg` | Gemini (confirmed by iolaire) | No authorship marker in the files, so this rests on the team's statement. All arrived in one commit (`2279741`). The generator scripts open with "Let's generate the requested SVG…" comments, consistent with an AI chat session. |
| `docs/Planning/Styles/create_svg_samples.py`, `create_ghost_svg_samples.py` | Gemini, same as the SVGs they produce | As above. |
| `GatekeepersWard/` Swift art code (`GhostGeometry`, `FigureRenderer`, `GateScene` and related) | Written with Kiro, ported from the SVG coordinates | Devlog Day 6 and the `castle-keep-visual-theme` spec. This is code under Apache 2.0, not a generated image. |
| `docs/Planning/Styles/drafts/*.png` (6 files) | Rendered by the project's own code (`GatekeepersWardTests/HUD/ArtDraftRenderer.swift`) | No C2PA data. These are render outputs of the vector code, not image-model output. |
| `docs/screenshots/Screenshot.png` | Screen capture of the running app | No C2PA data. |
| Menu bar icon, HUD banner | Drawn at runtime by the Swift art code | No image files in the repo. |

All of these are covered by the disclosure in the README, which says the art is AI-assisted. The Swift drawing code was written with Kiro and is licensed with the rest of the code.

## Scope and open items

- Applies to Gemini-generated images, the four mood-board JPGs, and the vector art derived from them.
- Every image and sprite is Gemini output, so the Google terms above cover all of them. The Kiro terms are not needed for the art, since Kiro only wrote the Swift code.
