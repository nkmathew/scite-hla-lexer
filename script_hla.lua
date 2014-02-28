--[[

Started:   25th February 2014
Completed: 28th February 2014

A SciTE script lexer for the HLA programming language
    http://en.wikipedia.org/wiki/High_Level_Assembly

Some good references that'll help when scripting SciTE with Lua:

    http://www.scintilla.org/ScintillaDoc.html
    http://www.scintilla.org/ScriptLexer.html
    http://lua-users.org/wiki/UsingLuaWithScite

    TODO: Implement Folding

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


digits            = props['hla.digits']
identifier_ends   = props['hla.valid.identifier.terminators']
identifier_starts = props['hla.valid.identifier.starters']
operators         = props['hla.operators']

attributes     = {}
booleans       = {}
conditionals   = {}
constants      = {}
directives     = {}
macros         = {}
registers      = {}
statements     = {}
task_markers   = {}
types          = {}
program_id     = {}
procedure_name = {}

function AddToTable(tbl)
  -- This function will be called by gsub with the matched substring as the
  -- first argument. That capture is added to the table with true as it's value
  -- so that testing for the existence of a key will be as easy as retrieving
  -- the key
  return function (capture)
    tbl[capture] = true
  end
end

-- Add a space at the end so that the last entry in the list of options will not
-- be left out when gsubed below
hla_attributes   = props['hla.attributes']       .. " "
hla_booleans     = props['hla.booleans']         .. " "
hla_conditionals = props['hla.conditionals']     .. " "
hla_constants    = props['hla.constants']        .. " "
hla_directives   = props['hla.directives']       .. " "
hla_macros       = props['hla.macros']           .. " "
hla_registers    = props['hla.registers']        .. " "
hla_statements   = props['hla.statements']       .. " "
hla_task_marker  = props['hla.task.markers']     .. " "
hla_types        = props['hla.data.declaration'] .. " "


-- Populate the tables with the words set in the .properties files
hla_attributes:gsub("(.-) "   , AddToTable(attributes))
hla_booleans:gsub("(.-) "     , AddToTable(booleans))
hla_conditionals:gsub("(.-) " , AddToTable(conditionals))
hla_constants:gsub("(.-) "    , AddToTable(constants))
hla_directives:gsub("(.-) "   , AddToTable(directives))
hla_macros:gsub("(.-) "       , AddToTable(macros))
hla_registers:gsub("(.-) "    , AddToTable(registers))
hla_statements:gsub("(.-) "   , AddToTable(statements))
hla_task_marker:gsub("(.-) "  , AddToTable(task_markers))
hla_types:gsub("(.-) "        , AddToTable(types))


function OnStyle(styler)
  styler:StartStyling(styler.startPos, styler.lengthDoc, styler.initStyle)

  -- Used to detect the programID. If the previous token is 'program', then the
  -- current token is the programID
  previous_state = nil
  previous_token = ""
  -- Used to tell whether we've finished colouring a task marker and can
  -- therefore restore the color to that of the comment type it is embedded in
  finished_with_marker = false
  -- Used to flag an error in a character string with more than one character
  characters_left = 1

  while styler:More() do
    curr_char = styler:Current()
    next_char = styler:Next()
    prev_char = styler:Previous()

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Switch OFF states ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if styler:AtLineEnd() and styler:State() == HLA_LINE_COMMENT then
      -- Line comments stop colouring at the end of the line
      styler:SetState(HLA_DEFAULT)
    end

    if (styler:State() == HLA_IDENTIFIER) and (previous_state ~= nil) and
      -- Placed here so that the state won't be switched off in the lines before
      -- we restore the comment's colour.
      curr_char:find("[ \n\r:]") then
      finished_with_marker = true
      styler:ChangeState(HLA_TASK_MARKER)
    end

    if finished_with_marker then
      -- Finished colouring task markers, restore the colouring of the original
      -- comment type(line or multiline)
      finished_with_marker = false
      styler:SetState(previous_state)
      previous_state = nil
    end

    if (styler:State() == HLA_CHARACTER) and (curr_char ~= "'") then
      -- Keep track of the number of characters in the character literal.
      characters_left = characters_left - 1
    end

    if not identifier_ends:find(curr_char, 1, true) and (styler:State() == HLA_IDENTIFIER) then
      -- HLA is a case 'neutral' language, 'PROGRAM' and 'program' are the same
      -- styler:Token() will fetch you all the characters before the current
      -- position that have the same style. It doesn't always fetch words
      -- separated by a space or operator.
      identifier = string.lower(styler:Token())
      -- Remove the sharp sign in a macro. An alternative to this would be
      -- adding '#' in the list of valid identifier characters.
      -- Colour the different tokens in the document
      identifier = identifier:gsub("#", "")

      -- Save the program ID and procedure name so that any subsequent
      -- occurrences will be highlighted.
      if previous_token == "program" then
        program_id[identifier] = true
      elseif previous_token == "procedure" then
        procedure_name[identifier] = true
      end

      if program_id[identifier] then
        -- Colour program ID
        styler:ChangeState(HLA_PROGRAM_ID)
      elseif procedure_name[identifier] then
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
      elseif statements[identifier] then
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
      previous_token = identifier
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
    elseif curr_char:find("[^0-9.e]") and (styler:State() == HLA_NUMBER) then
      -- Stop colouring numbers
      styler:SetState(HLA_DEFAULT)
    elseif styler:State() == HLA_OPERATOR then
      -- Stop colouring operators
      styler:SetState(HLA_DEFAULT)
    elseif curr_char == "/" and prev_char == "*" then
      -- Stop colouring a multiline comment
      styler:ForwardSetState(HLA_DEFAULT)
    end

    if (characters_left < 0) and (styler:State() == HLA_CHARACTER) then
      -- Colour the character string as an error because it has more than one
      -- character
      characters_left = 1
      styler:ChangeState(HLA_ERROR)
    end

    if (styler:State() == HLA_ERROR) and (curr_char == "'") then
      -- Restore the colour after highlighting the error
      styler:ForwardSetState(HLA_DEFAULT)
    end
    --~~~~~~~~~~~~~~~~~~~~~~~~~~~[ Switch ON states ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if styler:State() == HLA_DEFAULT then
      if styler:Match("'") then
      -- Found character
        characters_left = 1
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
      elseif identifier_starts:find(curr_char, 1, true) then
        styler:SetState(HLA_IDENTIFIER)
      elseif digits:find(curr_char, 1, true) then
        -- Start of a Number
        styler:SetState(HLA_NUMBER)
      elseif operators:find(curr_char, 1, true) then
        styler:SetState(HLA_OPERATOR)
      end
    end

    if IsTaskMarker(styler) and (styler:State() == HLA_LINE_COMMENT or
               styler:State() == HLA_MULTILINE_COMMENT) then
      -- Found a task marker, save the current state(comment type)
      previous_state = styler:State()
      styler:SetState(HLA_IDENTIFIER)
    end

    --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    -- Move forward one character
    styler:Forward()
  end
  -- Call it a night
  styler:EndStyling()
end

function IsTaskMarker(styler)
  for i, v in pairs(task_markers) do
    -- The table looks like this, {['MARKER'] = true, ....}
    if styler:Match(i) then
      return true
    end
  end
  return false
end

