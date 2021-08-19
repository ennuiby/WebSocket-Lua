script_name('Script Name')

------------------------require's-------------------------------------------------------

require 		'lib.moonloader'
require 		'lib.sampfuncs'

----------------------------------------------------------------------------------------


------------------------settings-------------------------------------------------------
local settings = {
	['server'] = '185.169.134.67:7777', -- where script work
	['ip'] = 'ws://localhost:3000',	-- ip of server WS 
	['url'] = 'http://localhost:3000' -- url of server
}

----------------------------------------------------------------------------------------

local lws, ws 			  = pcall(require, 'websocket')
local lcopas, copas       = pcall(require, "copas")
local lhttp, http         = pcall(require, 'copas.http')
local limgui, imgui       = pcall(require, 'imgui')
local lencoding, encoding = pcall(require, 'encoding')
local fass, fa 			  = pcall(require, 'fAwesome5')
local lwm, wm             = pcall(require, 'lib.windows.message')
local lkey, key           = pcall(require, 'vkeys')

---------------------------variables----------------------------------------------------

local serverStatus = '{ff0000}BAD'
local userData = {}
local online = {}

encoding.default = 'CP1251'
local u8 = encoding.UTF8

----------------------------------------------------------------------------------------

if lws then
	client = ws.client.copas({timeout = 2}) -- время ожидания ответа сервера.
end

if limgui then
	fa_glyph_ranges = imgui.ImGlyphRanges({ fa.min_range, fa.max_range })
	window = imgui.ImBool(false)
	tab = imgui.ImInt(1)
	tabs = {
		fa.ICON_FA_GLOBE_ASIA..u8' Основное',
		fa.ICON_FA_COGS..u8' Онлайн'
	}
end

function mtext(arg)
    sampAddChatMessage(script.this.name..' | '.. arg, 0xFFFFEE)
end

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
	local server = select(1, sampGetCurrentServerAddress())..":"..select(2, sampGetCurrentServerAddress())
	local mynick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    if server ~= settings['server'] then
		mtext('Планшет работает только на сервере '..settings['server'])
		thisScript():unload() 
		do return end
	end
    if lws then
		mtext('Ожидайте ответа от сервера. Максимальное время ожидания 120 секунд.')
		local connected, err = client:connect(settings['ip'], 'echo')
		if connected then
			userData = {
				server = server, 
				nick = mynick,
				serial = getSerial(),
				action = 'connect'
			}
			local connectToS = client:send(encodeJson(userData))
			responser()
		else
			mtext('Что-то пошло не так. Свяжитесь с разработчиком. Код: 500')
			thisScript():unload()
			do return end
		end
	end
	sampRegisterChatCommand("mhelp", function ()
		window.v = not window.v
	end)
	addEventHandler("onWindowMessage", function (msg, wparam, lparam)
        if (msg == 256 or msg == 257) and wparam == key.VK_ESCAPE and imgui.Process and not isPauseMenuActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() and not sampIsChatInputActive() then
            consumeWindowMessage(true, false)
            if msg == 257 then
				window.v = false
            end
        end
    end)
	while true do wait(0)
        imgui.Process = window.v
	end
end

function responser()
    lua_thread.create(function()
        while true do
			local message, opcode = client:receive()
			if message ~= nil then
				local data = decodeJson(message)
				for k, v in pairs(data) do
					if k == 'connection' then
						if v.isOk then
							mtext('Вы были успешно подключены. Ваш уникальный ID: '.. data.connection.id ..' /mhelp')
							getOnline()
							getServerStatus()
						else 
							mtext('Что-то пошло не так. Свяжитесь с разработчиком. Код: 401')
							thisScript():unload()
							do return end
						end
					end
					if k == 'online' then
						for k1, v1 in pairs(v) do
							online[k1] = v1
						end
					end
					if k == 'testconn' then
						if v.isOk then
							serverStatus = '{008000}OK'
						else
							serverStatus = '{ff0000}BAD'
						end
					end
				end
				message = nil
			end
		wait(150) end return
	end)
end

function getOnline()
    lua_thread.create(function()
        while true do
			local online = client:send(encodeJson({action = 'getonline'}))
		wait(1000) end return
	end)
end

function getServerStatus()
    lua_thread.create(function()
        while true do
			local sendS = client:send(encodeJson({action = 'testconn'}))
			print(sendS)
		wait(5000) end return
	end)
end


if limgui then
	function imgui.OnDrawFrame()
		local sw, sh = getScreenResolution()
		local btn_size = imgui.ImVec2(-0.1, 0)

		if window.v then
			imgui.SetNextWindowSize(imgui.ImVec2(700, 400), imgui.Cond.FirstUseEver)
			imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin('##window', window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar)
			imgui.Text(script.this.name .. u8' Информативное окно.')
			imgui.SameLine()
			imgui.TextColoredRGB('Статус подключения: '..serverStatus)
			imgui.SetCursorPos(imgui.ImVec2(0, 45))
			if imgui.CustomMenu(tabs, tab, imgui.ImVec2(135, 30)) then
				mtext('Вы нажали на элемент №'..tab.v)
			end
		
			imgui.SetCursorPos(imgui.ImVec2(150, 35))
			imgui.BeginChild('##main', imgui.ImVec2(530, 350), true)
			if tab.v == 1 then
				imgui.Text('hi')
			elseif tab.v == 2 then
				for k, v in pairs(online) do
					imgui.Text(v..'\n')
				end
			end
			imgui.EndChild()
			imgui.End()
		end
	end

	function imgui.CustomMenu(labels, selected, size, speed, centering)
		local bool = false
		speed = speed and speed or 0.2
		local radius = size.y * 0.50
		local draw_list = imgui.GetWindowDrawList()
		if LastActiveTime == nil then LastActiveTime = {} end
		if LastActive == nil then LastActive = {} end
		local function ImSaturate(f)
			return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
		end
		for i, v in ipairs(labels) do
			local c = imgui.GetCursorPos()
			local p = imgui.GetCursorScreenPos()
			if imgui.InvisibleButton(v..'##'..i, size) then
				selected.v = i
				LastActiveTime[v] = os.clock()
				LastActive[v] = true
				bool = true
			end
			imgui.SetCursorPos(c)
			local t = selected.v == i and 1.0 or 0.0
			if LastActive[v] then
				local time = os.clock() - LastActiveTime[v]
				if time <= 0.3 then
					local t_anim = ImSaturate(time / speed)
					t = selected.v == i and t_anim or 1.0 - t_anim
				else
					LastActive[v] = false
				end
			end
			local col_bg = imgui.GetColorU32(selected.v == i and imgui.GetStyle().Colors[imgui.Col.ButtonActive] or imgui.ImVec4(0,0,0,0))
			local col_box = imgui.GetColorU32(selected.v == i and imgui.GetStyle().Colors[imgui.Col.Button] or imgui.ImVec4(0,0,0,0))
			local col_hovered = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
			local col_hovered = imgui.GetColorU32(imgui.ImVec4(col_hovered.x, col_hovered.y, col_hovered.z, (imgui.IsItemHovered() and 0.2 or 0)))
			draw_list:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + t * size.x, p.y + size.y), col_bg, 10.0)
			draw_list:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + size.x, p.y + size.y), col_hovered, 10.0)
			draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x+5, p.y + size.y), col_box)
			imgui.SetCursorPos(imgui.ImVec2(c.x+(centering and (size.x-imgui.CalcTextSize(v).x)/2 or 15), c.y+(size.y-imgui.CalcTextSize(v).y)/2))
			imgui.Text(v)
			imgui.SetCursorPos(imgui.ImVec2(c.x, c.y+size.y))
		end
		return bool
	end

	function imgui.TextColoredRGB(text)
		local style = imgui.GetStyle()
		local colors = style.Colors
		local ImVec4 = imgui.ImVec4
	
		local explode_argb = function(argb)
			local a = bit.band(bit.rshift(argb, 24), 0xFF)
			local r = bit.band(bit.rshift(argb, 16), 0xFF)
			local g = bit.band(bit.rshift(argb, 8), 0xFF)
			local b = bit.band(argb, 0xFF)
			return a, r, g, b
		end
	
		local getcolor = function(color)
			if color:sub(1, 6):upper() == 'SSSSSS' then
				local r, g, b = colors[1].x, colors[1].y, colors[1].z
				local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
				return ImVec4(r, g, b, a / 255)
			end
			local color = type(color) == 'string' and tonumber(color, 16) or color
			if type(color) ~= 'number' then return end
			local r, g, b, a = explode_argb(color)
			return imgui.ImColor(r, g, b, a):GetVec4()
		end
	
		local render_text = function(text_)
			for w in text_:gmatch('[^\r\n]+') do
				local text, colors_, m = {}, {}, 1
				w = w:gsub('{(......)}', '{%1FF}')
				while w:find('{........}') do
					local n, k = w:find('{........}')
					local color = getcolor(w:sub(n + 1, k - 1))
					if color then
						text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
						colors_[#colors_ + 1] = color
						m = n
					end
					w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
				end
				if text[0] then
					for i = 0, #text do
						imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
						imgui.SameLine(nil, 0)
					end
					imgui.NewLine()
				else imgui.Text(u8(w)) end
			end
		end
	
		render_text(text)
	end

	function imgui.BeforeDrawFrame()
		if fa_font == nil then
			local font_config = imgui.ImFontConfig()
			font_config.MergeMode = true

			fa_font = imgui.GetIO().Fonts:AddFontFromFileTTF('moonloader/lib/fa-solid-900.ttf', 12.0, font_config, fa_glyph_ranges)
		end
	end
end

function getSerial()
    local ffi = require("ffi")
    ffi.cdef[[
    int __stdcall GetVolumeInformationA(
        const char* lpRootPathName,
        char* lpVolumeNameBuffer,
        uint32_t nVolumeNameSize,
        uint32_t* lpVolumeSerialNumber,
        uint32_t* lpMaximumComponentLength,
        uint32_t* lpFileSystemFlags,
        char* lpFileSystemNameBuffer,
        uint32_t nFileSystemNameSize
    );
    ]]
    local serial = ffi.new("unsigned long[1]", 0)
    ffi.C.GetVolumeInformationA(nil, nil, 0, serial, nil, nil, nil, 0)
    serial = serial[0]
    return serial
end