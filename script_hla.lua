--[[

Started:   25th February 2014
Completed: 28th February 2014

A SciTE script lexer for the HLA programming language
    http://en.wikipedia.org/wiki/High_Level_Assembly

Some good references that'll help when scripting SciTE with Lua:

    http://www.scintilla.org/ScintillaDoc.html
    http://www.scintilla.org/ScriptLexer.html
    http://lua-users.org/wiki/UsingLuaWithScite

]]

HLA_DEFAULT           = 0
HLA_BOOLEAN           = 1
HLA_CONSTANT          = 2
HLA_NUMBER            = 3
HLA_ERROR             = 4
HLA_CHARACTER         = 5
HLA_DOUBLE_STRING     = 6
HLA_LINE_COMMENT      = 7
HLA_MULTILINE_COMMENT = 8
HLA_REGISTER          = 9
HLA_DATA_DEFINITION   = 10
HLA_PROGRAM_ID        = 11
HLA_PROCEDURE_NAME    = 12
HLA_TASK_MARKER       = 13
HLA_IDENTIFIER        = 14
HLA_OPERATOR          = 15
HLA_DIRECTIVE         = 16
HLA_CONDITIONAL       = 17
HLA_STATEMENT         = 18
HLA_MACRO             = 19
HLA_ATTRIBUTE         = 20

attributes     = {}
booleans       = {}
conditionals   = {}
constants      = {}
directives     = {}
macros         = {}
registers      = {}
statements     = {}
taskMarkers    = {}
types          = {}
programId      = {}
procedureName  = {}

function AddToTable(tbl)
  -- This function will be called by gsub with the matched substring as the
  -- first argument. That capture is added to the table with true as it's value
  -- so that testing for the existence of a key will be as easy as retrieving
  -- the key
  return function (capture)
    tbl[capture] = true
  end
end

function loadProperties()
  -- Add a space at the end so that the last entry in the list of options will not
  -- be left out when gsubed below
  hlaAttributes     = props['hla.attributes']       .. " "
  hlaBooleans       = props['hla.booleans']         .. " "
  hlaConditionals   = props['hla.conditionals']     .. " "
  hlaConstants      = props['hla.constants']        .. " "
  hlaDirectives     = props['hla.directives']       .. " "
  hlaMacros         = props['hla.macros']           .. " "
  hlaRegisters      = props['hla.registers']        .. " "
  hlaStatements     = props['hla.statements']       .. " "
  hlaTaskMarker     = props['hla.task.markers']     .. " "
  hlaTypes          = props['hla.data.declaration'] .. " "

  digits            = props['hla.digits']
  foldCompact       = props["fold.compact"]
  identifierEnds    = props['hla.valid.identifier.terminators']
  identifierStarts  = props['hla.valid.identifier.starters']
  operators         = props['hla.operators']

  -- Populate the tables with the words set in the .properties files
  hlaAttributes:gsub("(.-) " , AddToTable(attributes))
  hlaBooleans:gsub("(.-) "   , AddToTable(booleans))
  hlaConditionals:gsub("(.-) ", AddToTable(conditionals))
  hlaConstants:gsub("(.-) "  , AddToTable(constants))
  hlaDirectives:gsub("(.-) " , AddToTable(directives))
  hlaMacros:gsub("(.-) "     , AddToTable(macros))
  hlaRegisters:gsub("(.-) "  , AddToTable(registers))
  hlaStatements:gsub("(.-) " , AddToTable(statements))
  hlaTaskMarker:gsub("(.-) " , AddToTable(taskMarkers))
  hlaTypes:gsub("(.-) "      , AddToTable(types))
end

-- Load settings
-- FIXME: Placing this function inside OnStyle causes the program ID
-- not to be coloured after modification of the .properties file.
loadProperties()

function OnStyle(styler)
  styler:StartStyling(styler.startPos, styler.lengthDoc, styler.initStyle)

  -- Used to detect the programID. If the previous token is 'program', then the
  -- current token is the programID
  local previousState = nil
  local previousToken = ""
  -- Used to tell whether we've finished colouring a task marker and can
  -- therefore restore the color to that of the comment type it is embedded in
  local finishedWithMarker = false
  -- Used to flag an error in a character string with more than one character
  local charactersLeft = 1

  while styler:More() do
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Switch OFF states ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if styler:AtLineEnd() and styler:State() == HLA_LINE_COMMENT then
      -- Line comments stop colouring at the end of the line
      styler:SetState(HLA_DEFAULT)
    end

    if (styler:State() == HLA_IDENTIFIER) and (previousState ~= nil) and
      -- Placed here so that the state won't be switched off in the lines before
      -- we restore the comment's colour.
      styler:Current():find("[ \n\r:]") then
      finishedWithMarker = true
      styler:ChangeState(HLA_TASK_MARKER)
    end

    if finishedWithMarker then
      -- Finished colouring task markers, restore the colouring of the original
      -- comment type(line or multiline)
      finishedWithMarker = false
      styler:SetState(previousState)
      previousState = nil
    end

    if (styler:State() == HLA_CHARACTER) and (styler:Current() ~= "'") then
      -- Keep track of the number of characters in the character literal.
      charactersLeft = charactersLeft - 1
    end

    if not identifierEnds:find(styler:Current(), 1, true) and (styler:State() == HLA_IDENTIFIER) then
      local _identifier = styler:Token()
      -- Remove the sharp sign in a macro. An alternative to this would be
      -- adding '#' in the list of valid identifier characters.
      -- Colour the different tokens in the document
      local identifier = _identifier:gsub("#", "")
      -- keywords like 'while' and 'begin' are case insensitive while statements
      -- like stdout.flushInput are case sensitive
      -- styler:Token() will fetch you all the characters before the current
      -- position that have the same style. It doesn't always fetch words
      -- separated by a space or operator.
      identifier = string.lower(identifier)

      -- Save the program ID and procedure name so that any subsequent
      -- occurrences will be highlighted.
      if previousToken == "program" then
        programId = {[identifier] = true}
      elseif previousToken == "procedure" then
        procedureName[identifier] = true
      end

      if programId[identifier] then
        -- Colour program ID
        styler:ChangeState(HLA_PROGRAM_ID)
      elseif procedureName[identifier] then
        -- Colour procedure name
        styler:ChangeState(HLA_PROCEDURE_NAME)
      elseif types[identifier] then
        -- Colour data definitions, int28, int32
        styler:ChangeState(HLA_DATA_DEFINITION)
      elseif constants[identifier] then
        -- Constant
        styler:ChangeState(HLA_CONSTANT)
      elseif booleans[identifier] then
        -- Boolean
        styler:ChangeState(HLA_BOOLEAN)
      elseif conditionals[identifier] then
        -- Conditional
        styler:ChangeState(HLA_CONDITIONAL)
      elseif directives[identifier] then
        -- Directive, emms
        styler:ChangeState(HLA_DIRECTIVE)
      elseif statements[_identifier] then
        -- Statement, e.g. stdout.put
        styler:ChangeState(HLA_STATEMENT)
      elseif macros[identifier] then
        -- Macro, e.g. #include
        styler:ChangeState(HLA_MACRO)
      elseif attributes[identifier] then
        -- Attribute/function, e.g. @Size
        styler:ChangeState(HLA_ATTRIBUTE)
      elseif registers[identifier] then
        -- Registers
        styler:ChangeState(HLA_REGISTER)
      end
      styler:SetState(HLA_DEFAULT)
      previousToken = identifier
    end

    if styler:State() == HLA_CHARACTER then
      -- End of single quoted string
      if styler:Match("'") then
        -- Use ForwardSetState so that any state set in this branch will not be
        -- undone when control reaches the lines below.
        styler:ForwardSetState(HLA_DEFAULT)
      end
    elseif styler:State() == HLA_DOUBLE_STRING then
      if styler:Match('"') then
        -- End of double quoted string
        styler:ForwardSetState(HLA_DEFAULT)
      end
    elseif (styler:Current():find('[^0-9.e]') or styler:Current() == '.' and
               styler:Next() == '.') and (styler:State() == HLA_NUMBER) then
      -- Stop colouring numbers
      styler:SetState(HLA_DEFAULT)
    elseif styler:State() == HLA_OPERATOR then
      -- Stop colouring operators
      styler:SetState(HLA_DEFAULT)
    elseif styler:Current() == "/" and styler:Previous() == "*" then
      -- Stop colouring a multiline comment
      styler:ForwardSetState(HLA_DEFAULT)
    end

    if (charactersLeft < 0) and (styler:State() == HLA_CHARACTER) then
      -- Colour the character string as an error because it has more than one
      -- character
      charactersLeft = 1
      styler:ChangeState(HLA_ERROR)
    end

    if (styler:State() == HLA_ERROR) and (styler:Current() == "'") then
      -- Restore the colour after highlighting the error
      styler:ForwardSetState(HLA_DEFAULT)
    end
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Switch ON states ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if styler:State() == HLA_DEFAULT then
      if styler:Match("'") then
        -- Found character
        charactersLeft = 1
        styler:SetState(HLA_CHARACTER)
      elseif styler:Match('"') then
        -- Start of double quoted string
        styler:SetState(HLA_DOUBLE_STRING)
      elseif styler:Match("//") then
        -- Start of a line comment
        styler:SetState(HLA_LINE_COMMENT)
      elseif styler:Match("/*") then
        -- Start of a Multiline comment
        styler:SetState(HLA_MULTILINE_COMMENT)
      elseif identifierStarts:find(styler:Current(), 1, true) then
        styler:SetState(HLA_IDENTIFIER)
      elseif digits:find(styler:Current(), 1, true) then
        -- Start of a Number
        styler:SetState(HLA_NUMBER)
      elseif operators:find(styler:Current(), 1, true) then
        styler:SetState(HLA_OPERATOR)
      end
    end

    if IsTaskMarker(styler) and (styler:State() == HLA_LINE_COMMENT or
               styler:State() == HLA_MULTILINE_COMMENT) then
      -- Found a task marker, save the current state(comment type)
      previousState = styler:State()
      styler:SetState(HLA_IDENTIFIER)
    end

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Move forward one character
    FoldDocument(styler)
    styler:Forward()
  end
  -- Call it a night
  styler:EndStyling()
end

function IsTaskMarker(styler)
  for i, v in pairs(taskMarkers) do
    -- The table looks like this, {['MARKER'] = true, ....}
    if styler:Match(i) then
      return true
    end
  end
  return false
end

--[[
    SC_FOLDLEVELHEADERFLAG = 0x2000 | 8192 | 0b10000000000000
    SC_FOLDLEVELWHITEFLAG  = 0x1000 | 4096 | 0b1000000000000
    SC_FOLDLEVELNUMBERMASK = 0xFFF  | 4095 | 0b111111111111
    SC_FOLDLEVELBASE       = 0x400  | 1024 | 0b10000000000
]]


function isNotWhitespace(char)
  local ord = string.byte(char)
  return not ((ord == 32) or ((ord >= 9) and (ord <= 13)))
end

visibleChars   = 0
currentLevel   = 0  -- A global variable to track fold levels
prevFoldLevel  = currentLevel
function FoldDocument(styler)
  -- Called every time the styler loop moves forward one character
  -- Folding is done at the end of the line
  local charOffset     = styler:Position()
  local lineNumber     = styler:Line(charOffset)
  local currStyle      = styler:State()
  local currChar       = styler:Current()

  --~~~~~~~~~~~~~~~~~~~~~~~~[ Track foldpoints ]~~~~~~~~~~~~~~~
  if currStyle == HLA_IDENTIFIER then
    if styler:Match("begin") then
      currentLevel = currentLevel + 1
    elseif styler:Match("end") then
      currentLevel = currentLevel - 1
    end
  end

  if currStyle == HLA_OPERATOR then
    -- Fold brackets
    if currChar:find("[{(]") then
      currentLevel = currentLevel + 1
    elseif currChar:find("[})]") then
      currentLevel = currentLevel - 1
    end
  end

  if currStyle == HLA_MULTILINE_COMMENT then
    -- Fold multiline comments
    if styler:Match("/*") then
      currentLevel = currentLevel + 1
    elseif styler:Match("*/") then
      currentLevel = currentLevel - 1
    end
  end

  if currentLevel < 0 then
    -- Prevent the fold level from dropping below zero. It won't work as
    -- expected without this
    currentLevel = 0
  end
  --~~~~~~~~~~~~~~~~~~~~~~~~~[ FOLD ]~~~~~~~~~~~~~~~~~~~~~~~~~~
  lev = prevFoldLevel
  if styler:AtLineEnd() then
    -- All folding is done at the end of the line
    if (visibleChars == 0) and (foldCompact == '1') then
      -- Don't fold this line because it's all whitespace
      lev = lev + SC_FOLDLEVELWHITEFLAG
    end
    if (currentLevel > prevFoldLevel) then
      lev = lev + SC_FOLDLEVELHEADERFLAG
    end
    if lev ~= styler:LevelAt(lineNumber) then
      styler:SetLevelAt(lineNumber, lev)
    end
    prevFoldLevel = currentLevel
    visibleChars = 0
  end
  if isNotWhitespace(currChar) then
    visibleChars = visibleChars + 1
  end
end

