--[[
  YouTube Live Stats (OBS Lua)
  ----------------------------
  Fetches YouTube stats and updates 3 Text (GDI+) or Text (FreeType 2) sources.

  ✅ Uses OBS built-in HTTP (no cmd pop-ups)
  ✅ Works on Windows, macOS, Linux

  Author: MMLTech
  Support: https://ko-fi.com/mmltech | https://paypal.me/mmltools
--]]

local obs = obslua

local video_id      = ""
local api_key       = ""
local poll_seconds  = 15
local src_likes     = ""
local src_views     = ""
local src_viewers   = ""
local timer_active  = false

local font_face     = ""
local font_size     = 0
local font_flags    = 0   
local font_style    = ""  

local text_color    = 0xFFFFFFFF
local apply_format  = true

local URL_TUTORIAL = "https://obscountdown.com/youtube-live-likes-counter-obs-studio#tutorial"
local URL_KOFI     = "https://ko-fi.com/mmltech"
local URL_PAYPAL   = "https://paypal.me/mmltools"

local function open_url(u)
  if not u or u == "" then return end
  local is_windows = package.config:sub(1,1) == "\\"

  if is_windows then
    local cmd = string.format('rundll32 url.dll,FileProtocolHandler "%s"', u)
    local h = io.popen(cmd, "r")
    if h then h:close() end
  else
    local cmd = string.format('open "%s" >/dev/null 2>&1 &', u)
    local ok = os.execute(cmd)
    if not ok then
      cmd = string.format('xdg-open "%s" >/dev/null 2>&1 &', u)
      os.execute(cmd)
    end
  end
end

local function sanitize(n) return (n and n ~= "") and tostring(n) or "-" end

local function build_url()
  return string.format(
    "https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,liveStreamingDetails&id=%s&key=%s",
    video_id, api_key
  )
end

local function ensure_in_active_scene(source)
  if not source then return end
  local scene_source = obs.obs_frontend_get_current_scene()
  if not scene_source then return end
  local scene = obs.obs_scene_from_source(scene_source)
  if not scene then obs.obs_source_release(scene_source); return end

  local name = obs.obs_source_get_name(source)
  local items = obs.obs_scene_enum_items(scene)
  local exists = false
  if items then
    for _, it in ipairs(items) do
      local s = obs.obs_sceneitem_get_source(it)
      if s and obs.obs_source_get_name(s) == name then
        exists = true
        break
      end
    end
    obs.sceneitem_list_release(items)
  end
  if not exists then obs.obs_scene_add(scene, source) end
  obs.obs_source_release(scene_source)
end

local function ensure_text_source(name)
  if not name or name == "" then return nil end

  local existing = obs.obs_get_source_by_name(name)
  if existing ~= nil then
    ensure_in_active_scene(existing)
    obs.obs_source_release(existing)
    return true
  end

  local id = "text_gdiplus_v2"
  if obs.obs_source_get_display_name(id) == nil then id = "text_gdiplus" end
  if obs.obs_source_get_display_name(id) == nil then id = "text_ft2_source" end

  local settings = obs.obs_data_create()
  obs.obs_data_set_string(settings, "text", "")
  obs.obs_data_set_int(settings, "color",  text_color)
  obs.obs_data_set_int(settings, "color1", text_color)

  local created = obs.obs_source_create(id, name, settings, nil)
  obs.obs_data_release(settings)

  if created ~= nil then
    ensure_in_active_scene(created)
    obs.obs_source_release(created)
    return true
  end
  return false
end

local function derive_flags(style, underline_bool, strikeout_bool)
  local flags = 0
  style = (style or ""):lower()
  if style:find("bold",   1, true) then flags = flags + 1 end   
  if style:find("italic", 1, true) then flags = flags + 2 end   
  if underline_bool                 then flags = flags + 4 end   
  if strikeout_bool                 then flags = flags + 8 end   
  return flags
end

local function apply_font_and_color_by_name(name)
  if not name or name == "" then return end
  local src = obs.obs_get_source_by_name(name)
  if src == nil then return end

  local s = obs.obs_source_get_settings(src)

  if font_face ~= "" or font_size > 0 or font_flags > 0 or font_style ~= "" then
    local f = obs.obs_data_create()
    if font_face  ~= "" then obs.obs_data_set_string(f, "face",  font_face)  end
    if font_size  >  0  then obs.obs_data_set_int(   f, "size",  font_size)  end
    if font_flags >= 0  then obs.obs_data_set_int(   f, "flags", font_flags) end
    if font_style ~= "" then obs.obs_data_set_string(f, "style", font_style) end
    obs.obs_data_set_obj(s, "font", f)
    obs.obs_data_release(f)
  end

  obs.obs_data_set_int(s, "color",  text_color)
  obs.obs_data_set_int(s, "color1", text_color)

  obs.obs_source_update(src, s)
  obs.obs_data_release(s)
  obs.obs_source_release(src)
end

local function get_text_sources()
  local list = {}
  local sources = obs.obs_enum_sources()
  if sources ~= nil then
    for _, s in ipairs(sources) do
      local id = obs.obs_source_get_unversioned_id(s)
      if id == "text_gdiplus_v2" or id == "text_gdiplus" or id == "text_ft2_source" then
        table.insert(list, obs.obs_source_get_name(s))
      end
    end
    obs.source_list_release(sources)
  end
  table.sort(list)
  return list
end

local function curl_fetch(url)
  if package.config:sub(1,1) ~= "\\" then
    local h = io.popen(string.format('curl -s -L "%s"', url), "r")
    if not h then return nil end
    local data = h:read("*a"); h:close(); return data
  end
  local ok, ffi = pcall(require, "ffi")
  if not ok then
    local h = io.popen(string.format('curl -s -L "%s"', url), "r")
    if not h then return nil end
    local data = h:read("*a"); h:close(); return data
  end
  if not rawget(_G, "__YTLUA_FFI_DEFINED__") then
    ffi.cdef[[
      typedef void* HANDLE; typedef int BOOL; typedef unsigned long DWORD;
      typedef unsigned short WORD; typedef unsigned char BYTE;
      typedef const wchar_t* LPCWSTR; typedef wchar_t* LPWSTR; typedef void* LPVOID;
      typedef struct _SECURITY_ATTRIBUTES{ DWORD nLength; void* lpSecurityDescriptor; BOOL bInheritHandle;} SECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
      typedef struct _STARTUPINFOW{ DWORD cb; wchar_t* lpReserved; wchar_t* lpDesktop; wchar_t* lpTitle; DWORD dwX; DWORD dwY; DWORD dwXSize; DWORD dwYSize; DWORD dwXCountChars; DWORD dwYCountChars; DWORD dwFillAttribute; DWORD dwFlags; WORD wShowWindow; WORD cbReserved2; BYTE* lpReserved2; HANDLE hStdInput; HANDLE hStdOutput; HANDLE hStdError;} STARTUPINFOW, *LPSTARTUPINFOW;
      typedef struct _PROCESS_INFORMATION{ HANDLE hProcess; HANDLE hThread; DWORD dwProcessId; DWORD dwThreadId;} PROCESS_INFORMATION, *LPPROCESS_INFORMATION;
      BOOL CreatePipe(HANDLE*, HANDLE*, LPSECURITY_ATTRIBUTES, DWORD);
      BOOL SetHandleInformation(HANDLE, DWORD, DWORD);
      BOOL CreateProcessW(LPCWSTR, LPWSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCWSTR, LPSTARTUPINFOW, LPPROCESS_INFORMATION);
      BOOL CloseHandle(HANDLE);
      DWORD WaitForSingleObject(HANDLE, DWORD);
      BOOL ReadFile(HANDLE, void*, DWORD, DWORD*, void*);
    ]]
    __YTLUA_FFI_DEFINED__ = true
  end
  local C = ffi.C
  local INVALID_HANDLE_VALUE = ffi.cast("HANDLE", -1)
  local INFINITE = 0xFFFFFFFF
  local STARTF_USESTDHANDLES = 0x00000100
  local CREATE_NO_WINDOW = 0x08000000
  local HANDLE_FLAG_INHERIT = 0x00000001

  local function wcs(s)
    local u16 = {}
    for i = 1, #s do u16[#u16 + 1] = string.byte(s, i) end
    local buf = ffi.new("wchar_t[?]", #u16 + 1)
    for i = 1, #u16 do buf[i - 1] = u16[i] end
    buf[#u16] = 0
    return buf
  end

  local sa = ffi.new("SECURITY_ATTRIBUTES")
  sa.nLength = ffi.sizeof(sa); sa.bInheritHandle = 1; sa.lpSecurityDescriptor = nil
  local hRead = ffi.new("HANDLE[1]"); local hWrite = ffi.new("HANDLE[1]")
  if C.CreatePipe(hRead, hWrite, sa, 0) == 0 then return nil end
  C.SetHandleInformation(hRead[0], HANDLE_FLAG_INHERIT, 0)

  local si = ffi.new("STARTUPINFOW")
  si.cb = ffi.sizeof(si); si.dwFlags = STARTF_USESTDHANDLES
  si.hStdInput  = INVALID_HANDLE_VALUE
  si.hStdOutput = hWrite[0]
  si.hStdError  = hWrite[0]

  local pi = ffi.new("PROCESS_INFORMATION")
  local cmdW = wcs(string.format('curl -s -L "%s"', url))
  local created = C.CreateProcessW(nil, cmdW, nil, nil, 1, CREATE_NO_WINDOW, nil, nil, si, pi)
  C.CloseHandle(hWrite[0])
  if created == 0 then C.CloseHandle(hRead[0]); return nil end

  local chunks = {}; local BUFSZ = 65536
  local buf = ffi.new("uint8_t[?]", BUFSZ); local bytesRead = ffi.new("DWORD[1]", 0)
  while true do
    local okr = C.ReadFile(hRead[0], buf, BUFSZ, bytesRead, nil)
    if okr == 0 or bytesRead[0] == 0 then break end
    chunks[#chunks+1] = ffi.string(buf, bytesRead[0])
  end
  C.WaitForSingleObject(pi.hProcess, INFINITE)
  C.CloseHandle(hRead[0]); C.CloseHandle(pi.hThread); C.CloseHandle(pi.hProcess)
  return table.concat(chunks)
end

local function set_text(name, text)
  if not name or name == "" then return end
  local src = obs.obs_get_source_by_name(name)
  if src ~= nil then
    local s = obs.obs_source_get_settings(src)
    obs.obs_data_set_string(s, "text", text)
    obs.obs_source_update(src, s)
    obs.obs_data_release(s)
    obs.obs_source_release(src)
  end
end

local function fetch_stats()
  if video_id == "" or api_key == "" then return end
  local body = curl_fetch(build_url())
  if not body or body == "" then
    obs.script_log(obs.LOG_WARNING, "YouTube fetch failed or empty.")
    return
  end

  local root = obs.obs_data_create_from_json(body)
  if not root then
    obs.script_log(obs.LOG_WARNING, "Invalid JSON from YouTube.")
    return
  end

  local items = obs.obs_data_get_array(root, "items")
  if not items then obs.obs_data_release(root); return end
  local first = obs.obs_data_array_item(items, 0)
  obs.obs_data_array_release(items)
  if not first then obs.obs_data_release(root); return end

  local stats = obs.obs_data_get_obj(first, "statistics")
  local live  = obs.obs_data_get_obj(first, "liveStreamingDetails")

  local likes   = stats and sanitize(obs.obs_data_get_string(stats, "likeCount")) or "-"
  local views   = stats and sanitize(obs.obs_data_get_string(stats, "viewCount")) or "-"
  local viewers = live  and sanitize(obs.obs_data_get_string(live, "concurrentViewers")) or "-"

  if stats then obs.obs_data_release(stats) end
  if live  then obs.obs_data_release(live)  end
  obs.obs_data_release(first)
  obs.obs_data_release(root)

  set_text(src_likes,   likes)
  set_text(src_views,   views)
  set_text(src_viewers, viewers)

  if apply_format then
    apply_font_and_color_by_name(src_likes)
    apply_font_and_color_by_name(src_views)
    apply_font_and_color_by_name(src_viewers)
  end
end

local likes_list, views_list, viewers_list

local function populate_source_lists(p_likes, p_views, p_viewers)
  local names = get_text_sources()
  local function repopulate(prop, current)
    obs.obs_property_list_clear(prop)
    for _, n in ipairs(names) do obs.obs_property_list_add_string(prop, n, n) end
    if current and current ~= "" then
      local found = false
      for _, n in ipairs(names) do if n == current then found = true break end end
      if not found then obs.obs_property_list_add_string(prop, current .. " (new)", current) end
    end
  end
  repopulate(p_likes,   src_likes)
  repopulate(p_views,   src_views)
  repopulate(p_viewers, src_viewers)
end

function script_description()
  return [[Fetch YouTube stats and update 3 Text sources (GDI+ / FreeType).]]
end

function script_properties()
  local p = obs.obs_properties_create()

  obs.obs_properties_add_text(p, "video_id", "YouTube Video ID", obs.OBS_TEXT_DEFAULT)
  obs.obs_properties_add_text(p, "api_key", "YouTube API Key", obs.OBS_TEXT_PASSWORD)
  obs.obs_properties_add_int(p, "poll_seconds", "Polling interval (s)", 5, 3600, 1)

  likes_list   = obs.obs_properties_add_list(p, "src_likes",   "Likes Source",   obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
  views_list   = obs.obs_properties_add_list(p, "src_views",   "Views Source",   obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
  viewers_list = obs.obs_properties_add_list(p, "src_viewers", "Viewers Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
  populate_source_lists(likes_list, views_list, viewers_list)

  obs.obs_properties_add_button(p, "refresh_and_create", "🔄 Refresh and create sources", function()
    if src_likes   and src_likes   ~= "" then ensure_text_source(src_likes)   end
    if src_views   and src_views   ~= "" then ensure_text_source(src_views)   end
    if src_viewers and src_viewers ~= "" then ensure_text_source(src_viewers) end
    populate_source_lists(likes_list, views_list, viewers_list)
    return true
  end)

  obs.obs_properties_add_font(p,  "font_selector", "Font")
  obs.obs_properties_add_color(p, "text_color",    "Color")

  obs.obs_properties_add_button(p, "apply_format_now", "🎨 Apply Formatting", function()
    apply_font_and_color_by_name(src_likes)
    apply_font_and_color_by_name(src_views)
    apply_font_and_color_by_name(src_viewers)
    return true
  end)
  
  obs.obs_properties_add_button(p, "btn_tutorial", "📖 Youtube API Key Tutorial", function()
    open_url(URL_TUTORIAL)
    return true
  end)

  obs.obs_properties_add_button(p, "btn_kofi", "☕ Buy me a Ko-fi", function()
    open_url(URL_KOFI)
    return true
  end)

  obs.obs_properties_add_button(p, "btn_paypal", "💳 Buy a Cookie on PayPal", function()
    open_url(URL_PAYPAL)
    return true
  end)

  return p
end

function script_defaults(s)
  obs.obs_data_set_default_int(s,  "poll_seconds", 15)
  obs.obs_data_set_default_bool(s, "apply_format", true)
  obs.obs_data_set_default_int(s,  "text_color",   0xFFFFFFFF)
end

local function restart_timer()
  if timer_active then obs.timer_remove(fetch_stats); timer_active = false end
  if poll_seconds < 5 then poll_seconds = 5 end
  obs.timer_add(fetch_stats, poll_seconds * 1000)
  timer_active = true
end

function script_update(s)
  video_id     = obs.obs_data_get_string(s, "video_id")
  api_key      = obs.obs_data_get_string(s, "api_key")
  poll_seconds = obs.obs_data_get_int(s,    "poll_seconds")

  src_likes    = obs.obs_data_get_string(s, "src_likes")
  src_views    = obs.obs_data_get_string(s, "src_views")
  src_viewers  = obs.obs_data_get_string(s, "src_viewers")

  local f = obs.obs_data_get_obj(s, "font_selector")
  if f ~= nil then
    font_face  = obs.obs_data_get_string(f, "face") or ""
    font_size  = obs.obs_data_get_int(f,    "size") or 0
    font_style = obs.obs_data_get_string(f, "style") or ""

    font_flags = obs.obs_data_get_int(f, "flags") or 0
    if font_flags == 0 then
      local underline = obs.obs_data_get_bool(f, "underline")
      local strikeout = obs.obs_data_get_bool(f, "strikeout")
      font_flags = derive_flags(font_style, underline, strikeout)
    end

    obs.obs_data_release(f)
  end

  text_color   = obs.obs_data_get_int(s, "text_color")
  apply_format = obs.obs_data_get_bool(s, "apply_format")

  restart_timer()
end

function script_load()
  restart_timer()
end

function script_unload()
  if timer_active then obs.timer_remove(fetch_stats) end
end
