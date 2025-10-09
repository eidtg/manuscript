local List = require 'pandoc.List'
local utils = require 'pandoc.utils'
local stringify = utils.stringify

-- Helper function to check if a table has a key
local function has_key(tbl, key)
  return tbl[key] ~= nil
end

-- Helper function to intercalate lists with separator
local function intercalate(lists, elem)
  local result = List:new{}
  for i = 1, (#lists - 1) do
    result:extend(lists[i])
    result:extend(elem)
  end
  if #lists > 0 then
    result:extend(lists[#lists])
  end
  return result
end

-- Default marks for different output formats
local default_marks = {
  corresponding_author = FORMAT == 'latex'
    and {pandoc.RawInline('latex', '\\textsuperscript{*}')}
    or FORMAT == 'typst'
    and {pandoc.RawInline('typst', 'super[*]')}
    or {pandoc.Str '*'},
  equal_contributor = FORMAT == 'latex'
    and {pandoc.RawInline('latex', '\\textsuperscript{†}')}
    or FORMAT == 'typst'
    and {pandoc.RawInline('typst', 'super[†]')}
    or {pandoc.Str '†'},
}

-- Check if author is corresponding author
local function is_corresponding_author(author)
  if has_key(author, "attributes") then
    return author.attributes["corresponding"] or (author.email ~= nil)
  end
  return author.email ~= nil
end

-- Check if author is equal contributor (co-first)
local function is_equal_contributor(author)
  if has_key(author, "attributes") then
    return author.attributes["equal-contributor"] or author.attributes["cofirst"]
  end
  return false
end

-- Normalize affiliations to add index numbers
local function normalize_affiliations(affiliations)
  if not affiliations then
    return {}
  end
  
  local affiliations_norm = List:new()
  for i, affil in ipairs(affiliations) do
    local norm_affil = {
      id = affil.id or pandoc.MetaString(tostring(i)),
      name = affil.name or affil,
      index = pandoc.MetaInlines(pandoc.Str(tostring(i))),
      number = tostring(i)
    }
    -- Handle different affiliation formats
    if type(affil) == "table" then
      if affil.name then
        norm_affil.name = affil.name
      elseif affil.department then
        local parts = {}
        if affil.department then table.insert(parts, stringify(affil.department)) end
        if affil.name then table.insert(parts, stringify(affil.name)) end
        if affil.city then table.insert(parts, stringify(affil.city)) end
        if affil.state then table.insert(parts, stringify(affil.state)) end
        if affil.country then table.insert(parts, stringify(affil.country)) end
        norm_affil.name = pandoc.MetaString(table.concat(parts, ", "))
      end
    end
    affiliations_norm:insert(norm_affil)
  end
  return affiliations_norm
end

-- Resolve author affiliations to indices
local function resolve_affiliations(author_affiliations, known_affiliations)
  if not author_affiliations or not known_affiliations then
    return {}
  end
  
  local result = List:new{}
  local affiliations_to_check = author_affiliations
  
  if type(author_affiliations) == "string" then
    affiliations_to_check = {author_affiliations}
  elseif type(author_affiliations) ~= "table" then
    return {}
  end
  
  for _, affil_id in ipairs(affiliations_to_check) do
    local affil_id_str = stringify(affil_id)
    for i, known_affil in ipairs(known_affiliations) do
      if stringify(known_affil.id) == affil_id_str then
        result:insert(pandoc.MetaString(tostring(i)))
        break
      end
    end
  end
  
  return result
end

-- Normalize authors with affiliation indices
local function normalize_authors(affiliations)
  return function(author)
    author.id = pandoc.MetaString(stringify(author.name))
    author.affiliations = resolve_affiliations(author.affiliations, affiliations)
    return author
  end
end

-- Create equal contributors block
local function create_equal_contributors_block(authors, mark)
  local has_equal_contribs = false
  for _, author in ipairs(authors) do
    if is_equal_contributor(author) then
      has_equal_contribs = true
      break
    end
  end
  
  if not has_equal_contribs then
    return nil
  end
  
  local contributors = {
    pandoc.Superscript(mark'equal_contributor'),
    pandoc.Space(),
    pandoc.Str 'These authors contributed equally to this work.'
  }
  
  -- Wrap with custom-style for DOCX
  return List:new{
    pandoc.Div(
      {pandoc.Para(contributors)},
      {['custom-style'] = 'Affiliation Meta'}
    )
  }
end

-- Create correspondence block
local function create_correspondence_blocks(authors, mark)
  local corresponding_authors = List:new{}
  
  for _, author in ipairs(authors) do
    if is_corresponding_author(author) then
      local author_name = stringify(author.name.literal or author.name)
      local author_parts = List:new{pandoc.Str(author_name)}
      
      if author.email then
        local mailto = 'mailto:' .. stringify(author.email)
        author_parts:extend({
          pandoc.Space(),
          pandoc.Str '<',
          pandoc.Link({pandoc.Str(stringify(author.email))}, mailto),
          pandoc.Str '>'
        })
      end
      
      table.insert(corresponding_authors, author_parts)
    end
  end
  
  if #corresponding_authors == 0 then
    return nil
  end
  
  local correspondence = List:new{
    pandoc.Superscript(mark'corresponding_author'),
    pandoc.Space(),
    pandoc.Str'Correspondence:',
    pandoc.Space()
  }
  
  local sep = List:new{pandoc.Str',', pandoc.Space()}
  
  -- Wrap with custom-style for DOCX
  return List:new{
    pandoc.Div(
      {pandoc.Para(correspondence .. intercalate(corresponding_authors, sep))},
      {['custom-style'] = 'Affiliation Meta'}
    )
  }
end

-- Create affiliations block
local function create_affiliations_blocks(affiliations)
  if not affiliations or #affiliations == 0 then
    return nil
  end
  
  local affil_lines = List:new()
  for i, affil in ipairs(affiliations) do
    local num_inlines = List:new{
      pandoc.Superscript{pandoc.Str(tostring(i))},
      pandoc.Space()
    }
    local affil_name = affil.name
    if type(affil_name) == "table" and affil_name.t == "MetaString" then
      affil_name = {pandoc.Str(stringify(affil_name))}
    elseif type(affil_name) == "string" then
      affil_name = {pandoc.Str(affil_name)}
    end
    affil_lines:insert(num_inlines .. List:new(affil_name))
  end
  
  -- Wrap with custom-style for DOCX
  return List:new{
    pandoc.Div(
      {pandoc.Para(intercalate(affil_lines, {pandoc.LineBreak()}))},
      {['custom-style'] = 'Affiliation Meta'}
    )
  }
end

-- Create abstract block from metadata
local function create_abstract_block(abstract_meta)
  if not abstract_meta then
    return nil
  end
  
  -- Create abstract header with custom style
  local abstract_header = pandoc.Div(
    {pandoc.Para({pandoc.Strong({pandoc.Str "Abstract"})})},
    {['custom-style'] = 'Abstract Title'}
  )
  
  -- Handle different abstract formats from metadata
  local abstract_content
  if type(abstract_meta) == "table" then
    if abstract_meta.t == "MetaInlines" then
      abstract_content = pandoc.Para(List:new(abstract_meta))
    elseif abstract_meta.t == "MetaBlocks" then
      -- For MetaBlocks, wrap all blocks in Abstract style
      local styled_blocks = List:new{}
      for _, block in ipairs(abstract_meta) do
        styled_blocks:insert(block)
      end
      return List:new{
        abstract_header,
        pandoc.Div(styled_blocks, {['custom-style'] = 'Abstract'})
      }
    elseif abstract_meta.t == "MetaString" then
      abstract_content = pandoc.Para({pandoc.Str(stringify(abstract_meta))})
    else
      abstract_content = pandoc.Para({pandoc.Str(stringify(abstract_meta))})
    end
  else
    abstract_content = pandoc.Para({pandoc.Str(stringify(abstract_meta))})
  end
  
  -- Wrap abstract content with custom style
  return List:new{
    abstract_header,
    pandoc.Div({abstract_content}, {['custom-style'] = 'Abstract'})
  }
end

-- Generate author inline with marks
local function author_inline_generator(get_mark)
  return function(author)
    local author_marks = List:new{}
    
    -- Add equal contributor mark
    if is_equal_contributor(author) then
      author_marks:insert(get_mark('equal_contributor'))
    end
    
    -- Add affiliation indices
    if author.affiliations then
      for _, idx in ipairs(author.affiliations) do
        local idx_str = stringify(idx)
        author_marks:insert({pandoc.Str(idx_str)})
      end
    end
    
    -- Add corresponding author mark
    if is_corresponding_author(author) then
      author_marks:insert(get_mark('corresponding_author'))
    end
    
    -- Build author name with marks
    local author_name = author.name.literal or author.name
    local name_inlines = List:new()
    
    if type(author_name) == "string" then
      name_inlines:insert(pandoc.Str(author_name))
    else
      name_inlines:extend(List:new(author_name))
    end
    
    if #author_marks > 0 then
      name_inlines:insert(pandoc.Superscript(intercalate(author_marks, {pandoc.Str ','})))
    end
    
    return name_inlines
  end
end

-- Create authors inline list
local function create_authors_inlines(authors, mark)
  local inlines_generator = author_inline_generator(mark)
  local inlines = List:new()
  
  for _, author in ipairs(authors) do
    inlines:insert(inlines_generator(author))
  end
  
  local and_str = List:new{pandoc.Space(), pandoc.Str'and', pandoc.Space()}
  
  if #inlines == 0 then
    return {}
  elseif #inlines == 1 then
    return inlines[1]
  else
    local last_author = inlines[#inlines]
    inlines[#inlines] = nil
    local result = intercalate(inlines, {pandoc.Str ',', pandoc.Space()})
    
    if #authors == 2 then
      result:extend(and_str)
    else
      result:extend(List:new{pandoc.Str ","} .. and_str)
    end
    result:extend(last_author)
    return result
  end
end

-- Main function
function Pandoc(doc)
  local meta = doc.meta
  local body = List:new{}
  
  local mark = function(mark_name) return default_marks[mark_name] end
  
  -- Store abstract before removing it from metadata
  local original_abstract = meta.abstract
  
  -- Process metadata
  if meta.affiliations then
    meta.affiliations = normalize_affiliations(meta.affiliations)
  end
  
  if meta.authors and meta.affiliations then
    meta.author = List:new(meta.authors):map(normalize_authors(meta.affiliations))
    
    -- Create author name block with Author style
    local author_inlines = create_authors_inlines(meta.author, mark)
    body:extend({
      pandoc.Div(
        {pandoc.Para(author_inlines)},
        {['custom-style'] = 'Author'}
      )
    })
    
    -- Create author-related blocks
    body:extend(create_equal_contributors_block(meta.authors, mark) or {})
    body:extend(create_affiliations_blocks(meta.affiliations) or {})
    body:extend(create_correspondence_blocks(meta.authors, mark) or {})
    
    -- Add abstract after author blocks
    if original_abstract then
      body:extend(create_abstract_block(original_abstract) or {})
    end
    
    -- Add regular document content
    body:extend(doc.blocks)
    
    -- Remove author from metadata since we've added it to body
    meta.author = nil
    
    -- Clean up - affiliations are now baked into the affiliations block
    meta.affiliations = nil
  else
    -- If no author processing needed, keep original structure
    if original_abstract then
      body:extend(create_abstract_block(original_abstract) or {})
    end
    body:extend(doc.blocks)
  end
  
  -- Remove abstract from metadata to prevent duplication
  meta.abstract = nil
  
  return pandoc.Pandoc(body, meta)
end