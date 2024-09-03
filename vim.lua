State = {
	activeIdx = 1,
	buffers = {},
	width = 10,
	height = 10,
	bufHeight = 9,
	shifted = false,
	ctrl = false,
	g = false,
	command = ""
}

Keys = {
	semicolon = 59,
	_0 = 48,
	_4 = 52,
	_6 = 54,
	a = 65,
	c = 67,
	i = 73,
	o = 89,
	q = 81,
	j = 74,
	k = 75,
	h = 72,
	l = 76,
	u = 85,
	g = 71,
	d = 68,
	l_brack = 91,
	enter = 257,
	backspace = 259,
	l_shift = 340,
	r_shift = 344,
	l_ctrl = 341,
	r_ctrl = 345,
}
Colors = {
	white = colors.toBlit(colors.white),
	black = colors.toBlit(colors.black),
	blue = colors.toBlit(colors.blue),
	orange = colors.toBlit(colors.orange),
	green = colors.toBlit(colors.green),
	yellow = colors.toBlit(colors.yellow),
}

Buffer = {}

function Buffer:new(path)
	local b = setmetatable({}, { __index = Buffer })

	b.lines = {}
	if path ~= nil then
		local file = io.open(path)
		for line in file:lines() do
			table.insert(b.lines, line)
		end
	end

	if #b.lines == 0 then
		b.lines = { "" }
	end

	b.x = 1
	b.y = 1
	b.scrollPos = 1
	b.mode = "normal"
	b.search = nil

	return b
end

function Buffer:scroll(n)
	self.scrollPos = self.scrollPos + n

	if self.scrollPos + State.bufHeight > #self.lines then
		self.scrollPos = #self.lines - State.bufHeight + 1
	end

	if self.scrollPos < 1 then
		self.scrollPos = 1
	end

	self.y = self.y + n
	if self.y < 1 then
		self.y = 1
	elseif self.y > #self.lines then
		self.y = #self.lines
	end
end

function Buffer:down(n)
	if self.y + n <= #self.lines then
		self.y = self.y + n
		if self.y >= self.scrollPos + State.height - 1 then
			self.scrollPos = self.scrollPos + n
			return true
		end
	end
	return false
end

function Buffer:up(n)
	if self.y - n >= 1 then
		self.y = self.y - n
		if self.y < self.scrollPos then
			self.scrollPos = self.y
			return true
		end
	end
	return false
end

function Buffer:left(n)
	self.x = self.x - n
	if self.x < 1 then
		self.x = 1
	end
end

function Buffer:right(n)
	self.x = self.x + n
	local line = self.lines[self.y]
	if self.x > line:len() then
		self.x = line:len()
	end
end

function Buffer:renderFull(term)
	term.clear()
	for i = 1, State.height - 1 do
		term.setCursorPos(1, i)
		local lineNum = i + self.scrollPos - 1
		if lineNum > #self.lines then
			break
		end
		term.write(self.lines[lineNum])
	end
end

function Buffer:renderCursor(term)
	local screenY = self.y - (self.scrollPos - 1)
	term.setCursorPos(self.x, screenY)
end

function Buffer:renderLine(term, line)
	if line < self.scrollPos then
		return
	end
	if line > self.scrollPos + State.bufHeight then
		return
	end
	term.setCursorPos(1, line - (self.scrollPos - 1))
	term.clearLine()
	term.write(self.lines[line])
end

function Buffer:renderSpan(term, start, finish)

end

local function updateTermSize()
	local width, height = term.getSize()
	State.width = width
	State.height = height
	State.bufHeight = height - 1
end

local function ab()
	return State.buffers[State.activeIdx]
end

local function renderStatus(text)
	term.setCursorPos(1, State.height)
	term.clearLine()
	local b = ab()
	if b.mode == "normal" then
		term.blit("N", Colors.white, Colors.blue)
		term.write(" ")
	elseif b.mode == "command" then
		term.blit("C", Colors.white, Colors.orange)
		term.write(" :")
	elseif b.mode == "visual" then
		term.blit("V", Colors.white, Colors.green)
	elseif b.mode == "insert" then
		term.blit("I", Colors.black, Colors.yellow)
		term.write(" ")
	end
	term.write(text or "")
	if b.mode == "normal" then
		term.setCursorPos(State.width - 20, State.height)
		term.write(("%d,%d(%d) %dx%d(%d)"):format(b.y, b.x, b.scrollPos, State.width, State.height,
			State.bufHeight))
	end
end

local function debugPrint(text)
	term.setCursorPos(1, State.height - 1)
	term.clearLine()
	term.write(text)
end

local function enterCommandMode()
	State.buffers[State.activeIdx].mode = "command"
	renderStatus("")
	term.setCursorPos(3, State.height)
	State.command = ""
end

local function enterNormalMode(msg)
	local b = ab();
	b.mode = "normal"
	local lineLen = b.lines[b.y]:len()
	if b.x > lineLen then
		b.x = lineLen
	end
	renderStatus(msg)
	term.setCursorPos(b.x, b.y)
end

local function enterInsertMode()
	local b = ab();
	b.mode = "insert"
	renderStatus("")
	term.setCursorPos(b.x, b.y)
end

local function handleKeyNormalModeG(key)
	local b = ab()
	if key == Keys.g then
		b.scrollPos = 1
		b.y = 1
		b:renderFull(term)
		renderStatus()
		b:renderCursor(term)
	end
	State.g = false
end

local function handleKeyNormalMode(key)
	if State.g then
		handleKeyNormalModeG(key)
	else
		local b = ab()
		if key == Keys.i then
			if State.shifted then
				-- move to beginning of text
			end
			os.queueEvent("mvim_mode", "insert")
		elseif key == Keys.a then
			if State.shifted then
				-- move to end of line
			end
			b.x = b.x + 1
			os.queueEvent("mvim_mode", "insert")
		elseif key == Keys.semicolon and State.shifted then
			os.queueEvent("mvim_mode", "command")
		elseif key == Keys.g and State.shifted then
			b.y = #b.lines
			b.scrollPos = #b.lines - State.bufHeight + 1
			b:renderFull(term)
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.g then
			State.g = true
		elseif key == Keys.j then
			if b:down(1) then
				b:renderFull(term)
			end
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.k then
			if b:up(1) then
				b:renderFull(term)
			end
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.h then
			b:left(1)
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.l then
			b:right(1)
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.u and State.ctrl then
			b:scroll(math.floor(-State.height / 2))
			b:renderFull(term)
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys.d and State.ctrl then
			b:scroll(math.floor(State.height / 2))
			b:renderFull(term)
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys._0 then
			b.x = 1
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys._4 and State.shifted then -- $
			b.x = #b.lines[b.y]
			renderStatus()
			b:renderCursor(term)
		elseif key == Keys._6 and State.shifted then -- ^
			local line = b.lines[b.y]
			local i = 1
			while i < #line do
				local c = line:sub(i, i)
				if c ~= " " and c ~= "\t" then
					break
				end
				i = i + 1
			end
			b.x = i
			renderStatus()
			b:renderCursor(term)
		end
	end
end

local function handleKeyInsertMode(key)
	if key == Keys.c and State.ctrl then
		os.queueEvent("mvim_mode", "normal")
	elseif key == Keys.l_brack and State.ctrl then
		os.queueEvent("mvim_mode", "normal")
	elseif key == Keys.enter then
		local b = ab()
		local line = b.lines[b.y]
		local _, spaces = string.find(line, "^[ ]+")
		if not spaces then
			spaces = 0
		end
		b.lines[b.y] = string.sub(line, 1, b.x - 1)
		table.insert(b.lines, b.y + 1, string.rep(' ', spaces) .. string.sub(line, b.x))
		b.x = spaces + 1
		b.y = b.y + 1
		b:renderFull(term)
		b:renderCursor(term)
	elseif key == Keys.backspace then
		local b = ab()
		if b.x > 1 then
			-- Remove character
			local line = b.lines[b.y]
			if b.x > 4 and string.sub(line, b.x - 4, b.x - 1) == "    " and not string.sub(line, 1, b.x - 1):find("%S") then
				b.lines[b.y] = string.sub(line, 1, b.x - 5) .. string.sub(line, b.x)
				b.x = b.x - 4
			else
				b.lines[b.y] = string.sub(line, 1, b.x - 2) .. string.sub(line, b.x)
				b.x = b.x - 1
			end
			b:renderLine(term, b.y)
		elseif b.y > 1 then
			-- Remove newline
			local prevLen = #b.lines[b.y - 1]
			b.lines[b.y - 1] = b.lines[b.y - 1] .. b.lines[b.y]
			table.remove(b.lines, b.y)
			b.x = prevLen + 1
			b.y = b.y - 1
			b:renderFull(term)
		end
		b:renderCursor(term)
	end
	-- TODO: Handle backspace
	-- TODO: Handle delete
end

local function evalCommand()
	if State.command == "q" then
		os.queueEvent("terminate")
	else
		os.queueEvent("mvim_mode", "normal", "Not an editor command: " .. State.command)
		State.command = ""
	end
end

local function handleKeyCommandMode(key)
	if key == Keys.c and State.ctrl then
		os.queueEvent("mvim_mode", "normal")
	elseif key == Keys.l_brack and State.ctrl then
		os.queueEvent("mvim_mode", "normal")
	elseif key == Keys.enter then
		evalCommand()
	elseif key == Keys.backspace then
		State.command = State.command:sub(1, State.command:len() - 1)
		renderStatus(State.command)
	end
end

local function handleKey(key, held)
	debugPrint(("%s (%d) held=%s"):format(keys.getName(key), key, held))
	local mode = ab().mode

	if key == Keys.l_shift or key == Keys.r_shift then
		State.shifted = true
	elseif key == Keys.l_ctrl or key == Keys.r_ctrl then
		State.ctrl = true
	elseif mode == "normal" then
		handleKeyNormalMode(key)
	elseif mode == "insert" then
		handleKeyInsertMode(key)
	elseif mode == "command" then
		handleKeyCommandMode(key)
	end
end

local function handleKeyUp(key)
	if key == Keys.l_shift or key == Keys.r_shift then
		State.shifted = false
	elseif key == Keys.l_ctrl or key == Keys.r_ctrl then
		State.ctrl = false
	end
end

local function handleChar(char)
	local b = ab()
	if b.mode == "command" then
		State.command = State.command .. char
		renderStatus(State.command)
	elseif b.mode == "insert" then
		local line = b.lines[b.y]
		b.lines[b.y] = line:sub(1, b.x - 1) .. char .. line:sub(b.x)
		b.x = b.x + 1
		b:renderLine(term, b.y)
		b:renderCursor(term)
	end
end

local function eventLoop()
	while true do
		local event, p1, p2 = os.pullEventRaw()
		if event == "key" then
			handleKey(p1, p2)
		elseif event == "char" then
			handleChar(p1)
		elseif event == "key_up" then
			handleKeyUp(p1)
		elseif event == "term_resize" then
			updateTermSize()
		elseif event == "mvim_mode" then
			if p1 == "insert" then
				enterInsertMode()
			elseif p1 == "command" then
				enterCommandMode()
			elseif p1 == "normal" then
				enterNormalMode(p2)
			end
		elseif event == "terminate" then
			term.clear()
			term.setCursorPos(1, 1)
			return
		end
	end
end

local function openBuffer(path)
	local b = Buffer:new(path)
	table.insert(State.buffers, b)
	State.activeIdx = #State.buffers
	b:renderFull(term)
	debugPrint(("There are %d buffers open."):format(#State.buffers))
end

local function printCenteredLine(text, term, y)
	local w, _ = term.getSize()
	local x = (w - text:len()) / 2
	term.setCursorPos(x, y)
	term.write(text)
end

local function openWelcome()
	term.clear()
	local lines = {
		"MVIM v0.1.0",
		"",
		"Mvim is is open source and freely distributable",
		"https://gitlab.com/findley/mvim",
		"",
		"type  :help mvim<Enter>  if you are new!",
		"type  :q<Enter>          to exit        ",
		"type  :help<Enter>       for help       ",
		"",
		"type :help news<Enter> to see changes in v0.1",
		"",
		"Help poor children in Uganda!",
		"type :help iccf<Enter>   for information",
	}
	local startLine = (State.height - #lines) / 2
	for i, text in pairs(lines) do
		printCenteredLine(text, term, startLine + i)
	end
	term.setCursorPos(1, 1)
	term.setCursorBlink(true)
	State.buffers = { Buffer:new(nil) }
	State.activeIdx = 1
end

local function printTable(t, indent)
	indent = indent or 0
	for k, v in pairs(t) do
		local formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting)
			printTable(v, indent + 1)
		else
			print(formatting .. tostring(v))
		end
	end
end

local function main(args)
	updateTermSize()
	openWelcome()
	enterNormalMode()
	if args[1] then
		openBuffer(args[1])
	end
	eventLoop()
end

main({ ... })
