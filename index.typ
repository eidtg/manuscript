// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

#let author-meta(
  ..affiliation,
  email: none,
  alias: none,
  address: none,
  cofirst: false
) = {
  let info = (
    "affiliation": affiliation
  )
  if email != none {
    info.insert("email", email)
  }
  if alias != none {
    info.insert("name", alias)
  }
  if address != none {
    info.insert("address", address)
  }
  if cofirst != none {
    info.insert("cofirst", cofirst)
  }
  info
}

#let default-title(title) = {
  show: block.with(width: 100%)
  set align(left)
  set text(size: 1.75em, weight: "bold")
  title
}

#let default-subtitle(subtitle) = {
  show: block.with(width: 100%)
  set align(left)
  set text(size: 1.25em, weight: "bold")
  subtitle
}

#let default-author(author) = {
  text(author.name)
  super(author.insts.map(it => str.from-unicode(97 + it)).join(","))
  if author.corresponding {
    footnote[
      Corresponding author. 
      #if author.email != none {
        [Email: #underline(author.email)]
      }
    ]
  }
  if author.cofirst == "thefirst" [
    #footnote("cofirst-author-mark") <fnt:cofirst-author>
  ] else if author.cofirst == "cofirst" [
    #footnote(<fnt:cofirst-author>)
  ]
}

#let default-affiliation(id, address) = {
  set text(size: 0.8em)
  super(str.from-unicode(97 + id))
  h(1pt)
  address
}

#let default-author-info(authors, affiliations) = {
  {
    show: block.with(width: 100%)
    authors.map(it => default-author(it)).join(", ")
  }
  let used_affiliations = authors.map(it => it.insts).flatten().dedup().map(it => affiliations.keys().at(it))
  {
    show: block.with(width: 100%)
    set par(leading: 0.4em)
    used_affiliations.enumerate().map(((ik, key)) => {
      default-affiliation(ik, affiliations.at(key))
    }).join(linebreak())
  }
}

#let default-abstract(abstract, keywords) = {
  // Abstract and keyword block
  if abstract != [] {
    stack(
      dir: ttb,
      spacing: 1em,
      ..([
        #heading([Abstract])
        #abstract
      ], if keywords.len() > 0 {
        text(weight: "bold", [Keywords: ])
        text([#keywords.join([; ]).])
      } else {none} )
    )
  }
  v(1em)
}

#let default-bibliography(bib) = {
  show bibliography: set text(1em)
  show bibliography: set par(first-line-indent: 0em)
  set bibliography(title: [References], style: "apa")
  bib
}

#let default-body(body) = {
  show heading.where(level: 1): set block(above: 1em, below: 1em)
  set par(first-line-indent: 0em)
  set par.line(numbering: "1")
  set figure(placement: none)
  set figure.caption(separator: " – ")
  show figure: it => layout(sz => {
    let w = measure(it.body, width: sz.width).width
    set par(justify: true)
    show figure.caption: cap => box(width: w, align(left, cap))
    it
  })
  show figure.where(kind: table): set figure.caption(position: top)
  set footnote(numbering: "1")
  body
}

#let article(
  // Article's Title
  title: "Article Title",
  subtitle: "Article Subtitle",
  
  // A dictionary of authors.
  // Dictionary keys are authors' names.
  // Dictionary values are meta data of every author, including
  // label(s) of affiliation(s), email, contact address,
  // or a self-defined name (to avoid name conflicts).
  // Once the email or address exists, the author(s) will be labelled
  // as the corresponding author(s), and their address will show in footnotes.
  // 
  // Example:
  // (
  //   "Auther Name": (
  //     "affiliation": "affil-1",
  //     "email": "author.name@example.com", // Optional
  //     "address": "Mail address",  // Optional
  //     "name": "Alias Name", // Optional
  //     "cofirst": false // Optional, identify whether this author is the co-first author
  //   )
  // )
  authors: ("Author Name": author-meta("affiliation-label")),

  // A dictionary of affiliation.
  // Dictionary keys are affiliations' labels.
  // These labels show be constent with those used in authors' meta data.
  // Dictionary values are addresses of every affiliation.
  //
  // Example:
  // (
  //   "affiliation-label": "Institution Name, University Name, Road, Post Code, Country"
  // )
  affiliations: ("affiliation-label": "Affiliation address"),

  // The paper's abstract.
  abstract: [],

  // The paper's keywords.
  keywords: (),

  // Templates for the following parts:
  // - `title`: how to show the title of this article.
  // - `author-list`: how to show the list of the authors.
  // - `author`: how to show each author's information.
  // - `affiliation`: how to show the affiliations.
  // - `abstract`: how to show the abstract and keywords.
  // - `bibliography`: how to show the bibliography.
  // - `body`: how to show main text.
  // Please see below for more infomation.
  template: (:),

  // Paper's content
  body
) = {
  // Set document properties
  set document(title: title, author: authors.keys())
  show footnote.entry: it => {
    let loc = it.note.location()
    stack(
      dir: ltr,
      spacing: 0.2em,
      box(width: it.indent, {
        set align(right)
        super(baseline: -0.2em, numbering(it.note.numbering, ..counter(footnote).at(loc)))
      }),
      it.note.body
    )
  }
  set footnote(numbering: "*")
  show "cofirst-author-mark": [These authors contributed equally to this work.]

  let template = (
    title: default-title,
    subtitle: default-subtitle,
    author-info: default-author-info,
    abstract: default-abstract,
    bibliography: default-bibliography,
    body: default-body,
    ..template,
  )

  // Title block
  (template.title)(title)
  (template.subtitle)(subtitle)

  set align(left)
  // Restore affiliations' keys for looking up later
  // to show superscript labels of affiliations for each author.
  let inst_keys = affiliations.keys()

  // Find co-fisrt authors
  let cofirst_index = authors.values().enumerate().filter(
    meta => "cofirst" in meta.at(1) and meta.at(1).at("cofirst") == true
  ).map(it => it.at(0))

  let author_list = ()

  // Authors and affiliations
  // Authors' block
  // Process the text for each author one by one
  for (ai, au) in authors.keys().enumerate() {
    let author_list_item = (
      name: none,
      insts: (),
      corresponding: false,
      cofirst: "no",
      address: none,
      email: none,
    )

    let au_meta = authors.at(au)
    // Write auther's name
    let aname = if au_meta.keys().contains("name") and au_meta.name != none {
      au_meta.name
    } else {
      au
    }
    author_list_item.insert("name", aname)
    
    // Get labels of author's affiliation
    let au_inst_id = au_meta.affiliation
    let au_inst_primary = ""
    // Test whether the author belongs to multiple affiliations
    if type(au_inst_id) == array {
      // If the author belongs to multiple affiliations,
      // record the first affiliation as the primary affiliation,
      au_inst_primary = affiliations.at(au_inst_id.first())
      // and convert each affiliation's label to index
      let au_inst_index = au_inst_id.map(id => inst_keys.position(key => key == id))
      // Output affiliation
      author_list_item.insert("insts", au_inst_index)
    } else if (type(au_inst_id) == str) {
      // If the author belongs to only one affiliation,
      // set this as the primary affiliation
      au_inst_primary = affiliations.at(au_inst_id)
      // convert the affiliation's label to index
      let au_inst_index = inst_keys.position(key => key == au_inst_id)
      // Output affiliation
      author_list_item.insert("insts", (au_inst_index,))
    }

    // Corresponding author
    if au_meta.keys().contains("email") or au_meta.keys().contains("address") {
      author_list_item.insert("corresponding", true)
      let address = if au_meta.keys().contains("address") and au_meta.address != "" {
        au_meta.address
      } else { au_inst_primary }
      author_list_item.insert("address", address)
      
      let email = if au_meta.keys().contains("email") and au_meta.email != none {
        au_meta.email
      } else { none }
      author_list_item.insert("email", email)
    }

    if cofirst_index.len() > 0 {
      if ai == 0 {
        author_list_item.insert("cofirst", "thefirst")
      } else if cofirst_index.contains(ai) {
        author_list_item.insert("cofirst", "cofirst")
      }
    }

    author_list.push(author_list_item)
  }

  (template.author-info)(author_list, affiliations)

  (template.abstract)(abstract, keywords)

  counter(footnote).update(0)

  show: template.body
  
  body
}

#let suffix(
  body
) = {
  set heading(numbering: none)
  body
}

#let appendix(
  body
) = context {
  counter(heading).update(0)
  set heading(numbering: "A.1.", supplement: "Appendix")
  show heading: it => context block(above: 1em, below: 1em, {
    if it.level == 1 {
      "Appendix " + counter(heading).display(it.numbering)
    } else {
      counter(heading).display(it.numbering)
    }
    h(4pt)
    it.body
  })
  show figure: set figure(numbering: (..nums) => context {
    (counter(heading.where(level: 1)).display("A"), ..nums.pos().map(str)).join(".")
  })
  body
}

#let booktab(
  ..args,
  top-bottom: 1pt,
  mid: 0.5pt
) = {
  show table.cell.where(y: 0): strong
  table(
    stroke: (x, y) => (
      top: if y == 0 { top-bottom } else if y == 1 { mid } else { 0pt },
    ),
    ..args,
    table.hline(stroke: top-bottom)
  )
}

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: article.with(
      title: "Manuscript Title"
  ,
      subtitle: "Manuscript Subtitle"
  ,
      authors: (
         "First Author": (
       name: "First Author",
       affiliation: ("Main Institution", "Secondary Institution"),
       email: "email\@adress.com",
       
       corresponding: true,
     ),
           "Second Author": (
       name: "Second Author",
       affiliation: ("Main Institution"),
       
       
       
     ),
        ),
    affiliations: (
        "Main Institution": "Department, Main Institution, City, Country",
        "Secondary Institution": "Department, Secondary Institution, City, Country",
      ),
    abstract: [This is an abstract …

],
  keywords: ("Keyword 1", "Keyword 2", "Keyword 3")
)

#pagebreak()
= Introduction
<introduction>
The Codex Regius of the Poetic Edda is one of the most important medieval Icelandic manuscripts @colombo_2022.

= Materials and Methods
<materials-and-methods>
= Results
<results>
= Discussion
<discussion>
= Conclusions
<conclusions>
#block[
#heading(
level: 
2
, 
numbering: 
none
, 
[
Authors contributions
]
)
]
#block[
#heading(
level: 
2
, 
numbering: 
none
, 
[
Fundind
]
)
]
#block[
#heading(
level: 
2
, 
numbering: 
none
, 
[
Competing interests
]
)
]
#pagebreak()
#block[
#heading(
level: 
2
, 
numbering: 
none
, 
[
Figures
]
)
]
#figure([
#link("https://the-public-domain-review.imgix.net/collections/yggdrasil-the-sacred-ash-tree-of-norse-mythology/oct_19_new_prints_00008.jpg?w=857")[#box(image("images/yggdrasil.jpg", width: 80.0%))]
], caption: figure.caption(
position: bottom, 
[
Oluf Olufsen Bagge - Yggdrasil, The Mundane Tree 1847
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-1>


#pagebreak()


 
  
#set bibliography(style: "draft.csl") 


#bibliography("references.bib")

