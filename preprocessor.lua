-- based on https://gist.github.com/incinirate/d52e03f453df94a65e1335d9c36d114e

local function trimS(s)
  return s:match("%s*(.+)")
end

local function stringRead( str, what, default )
  if( what == "string" )then
    return str:match("%S+")
  elseif( what == "stringInComma" )then
    return str:match("%b\"\"")
  elseif( what == "number")then
    return tonumber(str:match("%d+") or default)
  elseif( what == "string&arguments")then
    return str:match("%S+%b()")
  end
end

local insructions = {
  ["define"] = function(scope, inst)
    local command = trimS(inst:sub(7))
    local name = stringRead(command, "string")
    local nameCMD = stringRead(command, "string&arguments")
    if nameCMD then
      name = nameCMD
    end
    local fnSt, fnEnd, inner = name:find("(%b())")

    local rest = command:sub(#name + 2)

    local params
    if fnSt then
      name = name:sub(1, fnSt - 1)
      rest = command:sub(fnEnd + 2)

      local paramsS = inner:sub(2, #inner - 1)
      params = {}

      for param in paramsS:gmatch("[^%,%s]+") do
        params[#params + 1] = param
      end
    end

    scope[#scope + 1] = { name, rest, params }
  end,
  ["precompile"] = function(scope, inst)
    local command = trimS(inst:sub(11))
    local name = stringRead(command, "string")
    local nameCMD = stringRead(command, "string&arguments")
    if nameCMD then
      name = nameCMD
    end
    local fnSt, fnEnd, inner = name:find("(%b())")

    local rest = command:sub(#name + 2)

    local params
    if fnSt then
      name = name:sub(1, fnSt - 1)
      rest = command:sub(fnEnd + 2)

      local paramsS = inner:sub(2, #inner - 1)
      params = {}

      for param in paramsS:gmatch("[^%,%s]+") do
        params[#params + 1] = param
      end
    end
    scope[#scope + 1] = { name, rest, params, true }
  end,
  ["undef"] = function(scope, inst)
    local command = trimS(inst:sub(6))
    local name = stringRead(command, "string")

    for i = 1, #scope do
      if scope[i][1] == name then
        table.remove(scope, i)
        break
      end
    end
  end,
  ["ignore"] = function(scope, inst, lines, lineID)
    local command = trimS(inst:sub(7)) or ""
    local num = stringRead(command, "number", 1)

    for i = 1, num do
      table.remove(lines, 1)
      lineID = lineID + 1
    end
    return lineID
  end,
  
  ["ifdef"] = function(scope, inst, skipBlock)
    local command = trimS(inst:sub(6))
    local name = stringRead(command, "string")

    local found = false
    for i = 1, #scope do
      if scope[i][1] == name then
        found = true
        break
      end
    end

    if not found then
      skipBlock = skipBlock + 1
    end
    return skipBlock
  end,
  ["ifndef"] = function(scope, inst, skipBlock)
    local command = trimS(inst:sub(7))
    local name = stringRead(command, "string")

    local found = false
    for i = 1, #scope do
      if scope[i][1] == name then
        found = true
        break
      end
    end

    if found then
      skipBlock = skipBlock + 1
    end
    return skipBlock
  end,
  ["if"] = function(scope, inst, skipBlock)
    local command = trimS(inst:sub(3))
    local fn, er = loadstring("return (" .. command .. ")")

    if not fn then
      er = er and er:sub(er:find(":") + 4) or "Invalid conditional"
      print("Preprocessor parse error: (Line " .. lineID .. ")\n" .. er .. "\n")
    else
      local fscope = {}
      for i = 1, #scope do
        local val = scope[i][2]
        if tonumber(val) then val = tonumber(scope[i][2]) end
        fscope[scope[i][1]] = val
      end
      setfenv(fn, fscope)

      local succ, sret = pcall(fn)

      if not succ then
        sret = sret and sret:sub(sret:find(":") + 4) or "Invalid conditional"
        print("Preprocessor parse error: (Line " .. lineID .. ")\n" .. sret .. "\n")
        skipBlock = skipBlock + 1
      elseif not sret then
        skipBlock = skipBlock + 1
      end
    end
    return skipBlock
  end,
  ["else"] = function(scope, inst, skipBlock)
    skipBlock = skipBlock + 1
    return skipBlock
  end,
  ["endif"] = function(scope, inst, skipBlock)
    skipBlock = skipBlock - 1
    return skipBlock
  end,
  ["include"] = function(scope, inst, lines, lineID)
    local command = trimS(inst:sub(8))
    local inStr = stringRead(command, "stringInComma")
    if( not inStr )then
      inStr = stringRead(command, "string")
    end
    if inStr then

      local fileName = inStr:sub(2, #inStr - 1)
      local file = fileOpen(fileName)
      if file then
        local content = fileRead(file, fileGetSize(file)) .. "\n"
        fileClose(file)
        local contentLines = {}

        local lineID = 0
        for line in content:gmatch("([^\n]*)\n") do
          local lineContent = line:gsub("[\r\n]", "")
          if( string.len( lineContent ) > 0 )then
            lineID = lineID + 1
            table.insert( lines, lineID, lineContent )
          end
        end
      else
        print("Preprocessor parse error: (Line " .. lineID .. ")\nCannot find `" .. fn .. "'\n")
      end
    else
      print("Preprocessor parse error: (Line " .. lineID .. ")\nUnknown include strategy\n")
    end
  end,

}

local skipBlock = 0
local openInner = 0
local lines = {}
local final = {}
local scope = {}
local multiline = false
local lineID = 0

local function trimF(s)
  local fp = s:match("%s*(.+)")
  local sp = fp:reverse():match("%s*(.+)")
  return sp:reverse()
end

local function checkInstruction(instruction, swr)
  return instruction:sub(1, #swr) == swr
end

local function parenfind(str)
  local first = str:find("%(")
  if not first then
    return
  end

  local rest = str:sub(first + 1)
  local last

  local embed = 0
  for i = 1, #rest do
    local c = rest:sub(i, i)
    if c == "(" then
      embed = embed + 1
    elseif c == ")" then
      embed = embed - 1
      if embed == -1 then
        last = i
        break
      end
    end
  end

  if last then
    return first, first + last, str:sub(first, first + last)
  else
    return
  end
end

function expandMacros( line )
  local lineP = ""

  while line and #line > 0 do
    local c = line:sub(1, 1); line = line:sub(2)
    local p = line:sub(1, 1)
    if c == '"' or c == "'" then
      lineP = lineP .. c

      local escaping = false
      for char in line:gmatch(".") do
        lineP = lineP .. char
        line = line:sub(2)
        if char == c and not escaping then
          break
        elseif char == "\\" then
          escaping = true
        else
          escaping = false
        end
      end
    elseif c == "[" and p == "[" then
      multiline = true

      local endS = line:find("]]")
      if endS then
        lineP = lineP .. c .. line:sub(1, endS + 1)
        line = line:sub(endS + 2)
        multiline = false
      else
        lineP = lineP .. c .. line
        line = ""
      end
    else
      local nextS = line:find("[\"']")
      local nextM = line:find("%[%[")
      local next = math.min(nextS or #line + 1, nextM or #line + 1)

      local safe = c .. line:sub(1, next - 1)
      local safeOff = 0

      while #safe > 0 do
        local nextPKW, endPKW, functionName = safe:find("([%a_][%w_]*)")
        if nextPKW then
          lineP = lineP .. safe:sub(1, nextPKW - 1)
          safe = safe:sub(endPKW + 1)
          safeOff = safeOff + endPKW

          local found = false
          for i = 1, #scope do
            if scope[i][1] == functionName then
              if scope[i][3] then
                local s, e, tinner = parenfind(line:sub(safeOff))
                if e then
                  next = safeOff + e
                  safe = line:sub(safeOff + e, next - 1)
                  safeOff = safeOff + e
                end

                if s == 1 then
                  local paramsS = tinner:sub(2, #tinner - 1)
                  local params = {}

                  for param in paramsS:gmatch("[^%,]+") do
                    params[#params + 1] = trimF(param)
                  end

                  local modded = {}
                  local tempHold = {}
                  for k = 1, #scope[i][3] do
                    local v = scope[i][3][k]

                    local indTA = #scope + 1
                    for j = 1, #scope do
                      if v == scope[j][1] then
                        tempHold[j] = { scope[j][1], scope[j][2], scope[j][3] }
                        indTA = j
                        break
                      end
                    end

                    scope[indTA] = { v, params[k] }
                    modded[#modded + 1] = indTA
                  end
                  if( scope[i][4] )then
                    lineP = lineP .. (loadstring("return "..expandMacros(scope[i][2]))() or "")
                  else
                    lineP = lineP .. expandMacros(scope[i][2])
                  end

                  for p = 1, #modded do
                    local indER = modded[p]
                    if tempHold[indER] then
                      scope[indER] = tempHold[indER]
                    else
                      scope[indER] = nil
                    end
                  end
                  found = true
                  break
                else
                  print("Preprocessor WARNING: (Line " .. lineID .. ") `" .. functionName .. "' is a macro function, but is not called\n")
                  lineP = lineP .. expandMacros(scope[i][2])
                  found = true
                  break
                end
              else
                if( scope[i][4] )then
                  lineP = lineP .. (loadstring("return "..expandMacros(scope[i][2]))() or "")
                else
                  lineP = lineP .. expandMacros(scope[i][2])
                end
                found = true
                break
              end
            end
          end

          if not found then
            lineP = lineP .. functionName
          end
        else
          lineP = lineP .. safe
          safe = ""
        end
      end

      line = line:sub(next)
    end
  end

  return lineP
end

function parseLines( line )
  local splt = split(line,"\\\n")
  return table.concat(splt,"\n")
end

function preprocessor( data )
  final = {}

  scope = {}
  multiline = false
  lineID = 0

  skipBlock = 0
  openInner = 0
  lines = {}
  data = data.."\n"
  for line in data:gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  while #lines > 0 do
    local line = table.remove(lines, 1)
    local line = parseLines(line)
    if( string.len(line) > 0 )then
      lineID = lineID + 1
      if skipBlock > 0 then
        local trim = trimS(line) or ""
        if trim:sub(1, 1) == "#" then
          -- Preprocessor instruction
          local inst = trimS(trim:sub(2))
    
          if sw(inst, "else") then
            if openInner == 0 then
              skipBlock = skipBlock - 1
            end
          elseif sw(inst, "endif") then
            if openInner == 0 then
              skipBlock = skipBlock - 1
            else
              openInner = openInner - 1
            end
          elseif sw(inst, "ifndef") or sw(inst, "ifdef") then
            openInner = openInner + 1
          end
        end
      else
        if multiline then
          local endS = line:find("]]")
          if endS then
            table.insert(final, line:sub(1, endS + 1))
            line = line:sub(endS + 2)
            multiline = false
          else
            table.insert(final, line .. "\n")
            line = ""
          end
        else
          local trim = trimS(line) or ""
          if trim:sub(1, 1) == "#" then
            -- Preprocessor instruction
            local instruction = trimS(trim:sub(2))
            if checkInstruction(instruction, "include") then
              insructions["include"](scope, instruction, lines)
            elseif checkInstruction(instruction, "ignore") then
              lineID = insructions["ignore"](scope, instruction, lines, lineID)
            elseif checkInstruction(instruction, "define") then
              insructions["define"](scope, instruction)
            elseif checkInstruction(instruction, "precompile") then
              insructions["precompile"](scope, instruction)
            elseif checkInstruction(instruction, "undef") then
              insructions["undef"](scope, instruction)
            elseif checkInstruction(instruction, "ifdef") then
              skipBlock = insructions["ifdef"](scope, instruction, skipBlock)
            elseif checkInstruction(instruction, "ifndef") then
              skipBlock = insructions["ifndef"](scope, instruction, skipBlock)
            elseif checkInstruction(instruction, "if") then
              skipBlock = insructions["if"](scope, instruction, skipBlock)
            elseif checkInstruction(instruction, "else") then
              skipBlock = insructions["else"](scope, instruction, skipBlock)
            elseif checkInstruction(instruction, "endif") then
              skipBlock = insructions["endif"](scope, instruction, skipBlock)
            else
              print("Preprocessor parse error: (Line " .. lineID .. ")\nUnknown instruction `" .. instruction:match("%S+") .. "'\n")
            end
          else
            if( string.len(line) > 0 )then
              line = expandMacros(line)
              if( string.len(line) > 0 )then
                table.insert(final, line)
              end
            end
          end
        end
      end
    end
  end
  return table.concat(final, "\n")
end

function install()
  local thisResource = getResourceName(getThisResource())
  code = [=[
  function dofile( fileName )
    local file = fileOpen( fileName )
    local content = fileRead( file, fileGetSize( file ) )
    fileClose( file )
    local preprocessed = exports["]=]..thisResource..[=["]:preprocessor(content)
    local func = loadstring(preprocessed)
    if( func )then
      local status, err = pcall(func)
      if( err )then
        iprint("error",status,err)
      end
    else
      iprint("error loading ", fileName)
    end
  end
  function getstd(header)
    if( header )then
      return ":]=]..thisResource..[=[/std/"..header..".h"
    else
      return ":]=]..thisResource..[=[/std/std.h"
    end
  end
  ]=]
  return code
end