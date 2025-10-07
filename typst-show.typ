#show: article.with(
  $if(title)$
    title: "$title$"
  $else$
  none
  $endif$,
  $if(subtitle)$
    subtitle: "$subtitle$"
  $else$
  none
  $endif$,
  $if(by-author)$
    authors: (
  $for(by-author)$
  $if(it.name.literal)$
     "$it.name.literal$": (
       name: "$it.name.literal$",
       affiliation: ($for(it.affiliations)$"$it.id$"$sep$, $endfor$),
       $if(it.email)$email: "$it.email$",$endif$
       $if(it.address)$address: "$it.address$",$endif$
       $if(it.attributes.corresponding)$corresponding: $it.attributes.corresponding$,$endif$
       $if(it.attributes.equal-contributor)$equal-contributor: true,$endif$
     ),
  $endif$
  $endfor$
    ),
    affiliations: (
  $for(affiliations)$
      "$it.id$": "$it.department$, $it.name$, $it.city$$if(it.state)$, $it.state$$endif$, $it.country$",
  $endfor$
    ),
  $endif$
  abstract: $if(abstract)$[$abstract$]$else$[]$endif$,
  keywords: $if(keywords)$($for(keywords)$"$keywords$"$sep$, $endfor$)$else$()$endif$
)
