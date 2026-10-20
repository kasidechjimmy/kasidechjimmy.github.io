-- Keep hyphenated words (power-sharing, text-as-data, Post-War) on one line.
--
-- Browsers may end a line at the hyphen inside such a word, which looks as if
-- the word had been cut in half. This filter wraps every word that has a
-- hyphen between two letters in <span class="nowrap"> (the class is defined
-- in theme.scss), so the whole word moves to the next line instead.
-- Numbers such as the ORCID iD (0009-0007-...) are left alone.
--
-- It changes only the page text (doc.blocks), never the page settings
-- (metadata such as lang: en-GB), which must stay plain text.

-- The same holds for an en dash (–) between letters or digits, as in
-- year ranges (1989–2023) and pairs such as government–rebel.
local en_dash = "\226\128\147"

local function keep_whole(el)
  if el.text:find("%a%-%a") or el.text:find("%w" .. en_dash .. "%w") then
    return pandoc.Span({ el }, pandoc.Attr("", { "nowrap" }))
  end
end

function Pandoc(doc)
  doc.blocks = pandoc.Blocks(doc.blocks:walk({ Str = keep_whole }))
  return doc
end
