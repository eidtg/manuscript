## A Quarto Manuscript Template

This is a template repo for generating scientific manuscripts from Quarto. It combines and adapts several community resources:
- [Quarto Manuscripts tutorial](https://quarto.org/docs/manuscripts/authoring/vscode.html) was used as base structureo
- The ['quarto-preprint' extension, from Matti Vuorre,](https://github.com/mvuorre/quarto-preprint) and the ['typst-starter-journal-article' repo, from Yigong Hu,](https://github.com/HPDell/typst-starter-journal-article/tree/main) were partially incorporated to render the document as PDF using [Typst](https://typst.app/).
- The ['authors-block' repo, from Lorenz Kapsner,](https://github.com/kapsner/authors-block) was used for proper author metadata formatting when rendering as DOCX.

## Features

- Multi-format output: HTML, DOCX, and PDF (via Typst)
- Proper author metadata with affiliations, corresponding authors, and equal contributors
- Custom styling for DOCX output via reference template
- CSL citation support

## Usage
1. **Clone this repository**
2. **Edit the `index.qmd` file:**
   - Update the front matter with your manuscript details (title, authors, affiliations, etc.).
   - Write your manuscript content in Markdown format.
3. (_optional_) **Customizations:**
   - Modify `doc-template.docx` for DOCX styling.
   - Modify `typst-template.typ` for PDF styling.
   - Adjust `draft.csl` for bibliographic styles.
4. **Render the manuscript:**
   - Run `quarto render` or `quarto preview` to generate the outputs in the `_manuscript` folder.






