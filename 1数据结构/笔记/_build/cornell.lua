-- 康奈尔笔记 pandoc 过滤器：样式 span / 讲解框 div / 线索栏 / mermaid / 表格 / 课件截图
local BUILD = os.getenv('NOTES_BUILD') or '.'
local MMDC = os.getenv('MMDC') or 'mmdc'

local function latex_inlines(inls)
  return pandoc.write(pandoc.Pandoc({pandoc.Plain(inls)}), 'latex'):gsub('\n$', '')
end
local function latex_blocks(blks)
  return pandoc.write(pandoc.Pandoc(blks), 'latex'):gsub('\n$', '')
end

local span_cmd = {
  red = 'hlred', blue = 'hlblue', green = 'hlgreen', orange = 'hlorange', purple = 'hlpurple',
  u = 'uln', wave = 'wavy', mark = 'hlmark',
}
local tag_color = { tag = 'wdblue', tagred = 'wdred', taggreen = 'wdgreen', tagorange = 'wdorange', taggray = 'wdgray' }

local function Span(el)
  for _, c in ipairs(el.classes) do
    if span_cmd[c] then
      return pandoc.RawInline('latex', '\\' .. span_cmd[c] .. '{' .. latex_inlines(el.content) .. '}')
    end
    if tag_color[c] then
      return pandoc.RawInline('latex', '\\tagbox{' .. tag_color[c] .. '}{' .. latex_inlines(el.content) .. '}')
    end
  end
end

local function Q(c) return pandoc.RawInline('latex', c) end

local function Quoted(el)
  local l, r = '“', '”'
  if el.quotetype == 'SingleQuote' then l, r = '‘', '’' end
  local out = { Q(l) }
  for _, x in ipairs(el.content) do table.insert(out, x) end
  table.insert(out, Q(r))
  return out
end

local function Inlines(inls)
  local open = true
  local out = pandoc.Inlines({})
  for _, x in ipairs(inls) do
    if x.t == 'Str' and x.text:find('[\"“”]') then
      local buf = ''
      for _, ch in utf8.codes(x.text) do
        local c = utf8.char(ch)
        if c == '"' or c == '“' or c == '”' then
          if buf ~= '' then out:insert(pandoc.Str(buf)); buf = '' end
          local q = open and '“' or '”'
          open = (q == '”')
          out:insert(Q(q))
        else buf = buf .. c end
      end
      if buf ~= '' then out:insert(pandoc.Str(buf)) end
    else out:insert(x) end
  end
  return out
end

local function walk_inl(blocks)
  return pandoc.Div(blocks):walk({ Span = Span }).content
end

local box_env = {
  bridge = 'bridgebox', plain = 'plainbox', deep = 'deepbox', exam = 'exambox', pitfall = 'pitfallbox',
  book = 'bookbox', teacher = 'teacherbox', fix = 'fixbox', summary = 'summarybox',
  video = 'videobox', jiexi = 'jiexibox', add = 'addbox', recall = 'recallbox', watch = 'watchbox',
}

local function cue_latex(el, cmd)
  local blks = walk_inl(el.content)
  local inls = {}
  for i, b in ipairs(blks) do
    if b.content then
      if i > 1 then table.insert(inls, pandoc.RawInline('latex', '\\par ')) end
      for _, x in ipairs(b.content) do table.insert(inls, x) end
    end
  end
  return '\\' .. cmd .. '{' .. latex_inlines(inls) .. '}'
end

local function table_latex(tbl, widths)
  local ncol = #tbl.colspecs
  local w = {}
  if widths then
    for x in widths:gmatch('[%d%.]+') do table.insert(w, tonumber(x)) end
  end
  if #w ~= ncol then
    w = {}
    local any = false
    for i, cs in ipairs(tbl.colspecs) do
      local v = cs[2]
      if type(v) == 'number' and v > 0 then any = true end
      w[i] = (type(v) == 'number' and v > 0) and v or 0
    end
    if not any then for i = 1, ncol do w[i] = 1 end end
    for i = 1, ncol do if w[i] == 0 then w[i] = 1 / ncol end end
  end
  local sum = 0
  for i = 1, ncol do sum = sum + w[i] end
  local spec = {}
  for i = 1, ncol do
    table.insert(spec, string.format('>{\\hsize=%.3f\\hsize\\raggedright\\arraybackslash}X', w[i] * ncol / sum))
  end
  local function cell_tex(cell, header)
    local s = latex_blocks(walk_inl(cell.contents))
    s = s:gsub('\n\n', '\\newline '):gsub('\n', ' ')
    if header then s = '\\textcolor{white}{\\bfseries ' .. s .. '}' end
    return s
  end
  local nbody = 0
  for _, body in ipairs(tbl.bodies) do nbody = nbody + #body.body end
  local env = 'xltabular'
  local out = { '{\\rowcolors{2}{wdblue!5}{white}\\arrayrulecolor{wdblue!35}',
    (env == 'tabularx' and '\\par\\noindent' or '') .. '\\begin{' .. env .. '}{\\linewidth}{' .. table.concat(spec) .. '}' }
  local head_rows = tbl.head.rows
  if #head_rows > 0 then
    for _, row in ipairs(head_rows) do
      local cells = {}
      for _, c in ipairs(row.cells) do table.insert(cells, cell_tex(c, true)) end
      table.insert(out, '\\rowcolor{wdblue}' .. table.concat(cells, ' & ') .. ' \\\\')
    end
    table.insert(out, '\\endfirsthead')
  end
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      local cells = {}
      for _, c in ipairs(row.cells) do table.insert(cells, cell_tex(c, false)) end
      table.insert(out, table.concat(cells, ' & ') .. ' \\\\ \\hline')
    end
  end
  table.insert(out, '\\end{' .. env .. '}\\par\\vspace{4pt}}')
  return pandoc.RawBlock('latex', table.concat(out, '\n'))
end

local function mermaid(el)
  local hash = pandoc.utils.sha1(el.text)
  local out = BUILD .. '/cache/' .. hash .. '.pdf'
  local f = io.open(out, 'r')
  if f then f:close() else
    local src = BUILD .. '/cache/' .. hash .. '.mmd'
    local g = io.open(src, 'w'); g:write(el.text); g:close()
    local cmd = string.format('%s -q -p %s/puppeteer.json -c %s/mermaid-config.json -i %s -o %s --pdfFit -b transparent >/dev/null 2>&1',
      MMDC, BUILD, BUILD, src, out)
    os.execute(cmd)
  end
  local scale = el.attributes.scale or '0.85'
  local cap = el.attributes.caption and ('\\par\\vspace{2pt}{\\small\\color{wdgray}' .. el.attributes.caption .. '}') or ''
  return pandoc.RawBlock('latex', '\\begin{figure}[!ht]\\centering\\adjustimage{scale=' .. scale ..
    ',max width=\\linewidth,max height=0.6\\textheight}{' .. out .. '}' .. cap .. '\\end{figure}')
end

local function image_block(img)
  local width = img.attributes.width or '0.8'
  local cap = latex_inlines(walk_inl({ pandoc.Plain(img.caption) })[1].content)
  local cmd = img.classes:includes('plain') and 'plainfig' or 'slidefig'
  return pandoc.RawBlock('latex', '\\' .. cmd .. '{' .. img.src .. '}{' .. width .. '}{' .. cap .. '}')
end

local function single_image(blk)
  if (blk.t == 'Para' or blk.t == 'Plain') and #blk.content == 1 and blk.content[1].t == 'Image' then
    return blk.content[1]
  end
end

local function Figure(el)
  local b = el.content[1]
  local img = b and single_image(b)
  if img then
    if #img.caption == 0 and el.caption and el.caption.long and #el.caption.long > 0 then
      img.caption = pandoc.utils.blocks_to_inlines(el.caption.long)
    end
    return image_block(img)
  end
end

local function Para(el)
  local img = single_image(el)
  if img then return image_block(img) end
end

local function Div(el)
  if el.classes:includes('cue') then return pandoc.RawBlock('latex', '\\cueblock{\\cuenote}{' .. cue_latex(el, 'relax') .. '}') end
  if el.classes:includes('cuekey') then return pandoc.RawBlock('latex', '\\cueblock{\\cuekey}{' .. cue_latex(el, 'relax') .. '}') end
  if el.classes:includes('q') then
    local r = { pandoc.RawBlock('latex', '\\begin{questionbox}[' .. (el.attributes.title or '题目') .. ']') }
    for _, b in ipairs(el.content) do table.insert(r, b) end
    table.insert(r, pandoc.RawBlock('latex', '\\end{questionbox}'))
    return r
  end
  if el.classes:includes('def') then
    local t = el.attributes.title and ('[：' .. el.attributes.title .. ']') or ''
    local r = { pandoc.RawBlock('latex', '\\begin{defbox}' .. t) }
    for _, b in ipairs(el.content) do table.insert(r, b) end
    table.insert(r, pandoc.RawBlock('latex', '\\end{defbox}'))
    return r
  end
  for _, c in ipairs(el.classes) do
    if box_env[c] then
      local r = { pandoc.RawBlock('latex', '\\begin{' .. box_env[c] .. '}') }
      if el.attributes.title then
        r[1] = pandoc.RawBlock('latex', '\\begin{' .. box_env[c] .. '}\\textbf{' .. el.attributes.title .. '}\\par')
      end
      for _, b in ipairs(el.content) do table.insert(r, b) end
      table.insert(r, pandoc.RawBlock('latex', '\\end{' .. box_env[c] .. '}'))
      return r
    end
  end
end

local HAS_TOC = false
local function Meta(m)
  HAS_TOC = m.toc and pandoc.utils.stringify(m.toc) ~= 'false'
end
local function Header(el)
  if HAS_TOC and el.level == 1 then
    return { el, pandoc.RawBlock('latex', '\\tocback') }
  end
end

local function CodeBlock(el)
  if el.classes:includes('mermaid') then return mermaid(el) end
end

local function Table(el) return table_latex(el, el.attributes.widths) end

local function TblDiv(el)
  if el.classes:includes('tbl') then
    for _, b in ipairs(el.content) do
      if b.t == 'Table' then b.attributes.widths = el.attributes.widths end
    end
    return el.content
  end
end

local function CueMerge(blocks)
  local out = pandoc.Blocks({})
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    local nx = blocks[i + 1]
    if b.t == 'Div' and (b.classes:includes('cue') or b.classes:includes('cuekey')) and nx and nx.t == 'Para'
       and not single_image(nx) then
      local cmd = b.classes:includes('cue') and 'cuenote' or 'cuekey'
      local inl = pandoc.Inlines({ pandoc.RawInline('latex', cue_latex(b, cmd)) })
      inl:extend(nx.content)
      out:insert(pandoc.RawBlock('latex', '\\Needspace{4\\baselineskip}'))
      out:insert(pandoc.Para(inl))
      i = i + 2
    else
      if b.t == 'Div' and (b.classes:includes('cue') or b.classes:includes('cuekey')) and nx and nx.t == 'Div'
         and nx.classes:includes('q') then
        out:insert(pandoc.RawBlock('latex', '\\Needspace{8\\baselineskip}\\vspace{22pt}'))
      end
      out:insert(b); i = i + 1
    end
  end
  return out
end

return {
  { Meta = Meta },
  { Header = Header },
  { Quoted = Quoted },
  { Inlines = Inlines },
  { Blocks = CueMerge },
  { Span = Span },
  { Div = TblDiv },
  { CodeBlock = CodeBlock, Figure = Figure, Para = Para, Table = Table, Div = Div },
}
