dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')
local abortproject = false

local downloaded = {}
local addedtolist = {}
local userpics = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if (downloaded[url] ~= true and addedtolist[url] ~= true) and string.match(url, "^https?://[^/]*myvip%.com") and ((string.match(url, "[^0-9]"..item_value.."[0-9][0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9][0-9]")) or string.match(url, "pager=") or string.match(url, "^https?://avatar[0-9]*%.myvip%.com") or string.match(url, "^https?://image[0-9]*%.myvip%.com") or string.match(url, "^https?://thumbs%.myvip%.com") or html == 0) then
    if string.match(url, "^https?://avatar[0-9]*%.myvip%.com") then
      userpics[url] = true
      return false
    else
      addedtolist[url] = true
      return true
    end
  else
    return false
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and string.match(url, "^https?://[^/]*myvip%.com") and ((string.match(url, "[^0-9]"..item_value.."[0-9][0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9][0-9]")) or string.match(url, "pager=") or string.match(url, "^https?://avatar[0-9]*%.myvip%.com") or string.match(url, "^https?://image[0-9]*%.myvip%.com") or string.match(url, "^https?://thumbs%.myvip%.com")) then
      if string.match(url, "^https?://avatar[0-9]*%.myvip%.com") then
        userpics[url] = true
      elseif string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^//") then
      check("http:"..newurl)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if not (string.match(newurl, "^https?://") or string.match(newurl, "^/") or string.match(newurl, "^javascript:") or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end
  
  if item_type == '100users' and string.match(url, "^https?://[^/]*myvip%.com") and not (string.match(url, "^https?://avatar[0-9]*%.myvip%.com") or string.match(url, "^https?://image[0-9]*%.myvip%.com") or string.match(url, "^https?://thumbs%.myvip%.com")) then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, "&#34;(.-)&#34;") do
      if downloaded[newurl] ~= true and addedtolist[newurl] ~= true and string.match(newurl, "^https?:././avatar[0-9]*%.myvip%.com./users./") then
        table.insert(urls, { url=string.gsub(newurl, "./", "/") })
        addedtolist[string.gsub(newurl, "./", "/")] = true
      else
        checknewurl(string.gsub(newurl, "./", "/"))
      end
    end
    if string.match(url, "pager=") then
      local usercount = 0
      for newuser in string.gmatch(html, "list%-row%-card%-avatar") do
        usercount = usercount + 1
      end
      if usercount == 5 then
        io.stdout:write("ABORTING because of a 'usercount' of 5.\n")
        io.stdout:flush()
        abortproject = true
      end
    end
    if string.match(url, "^https?://[^/]*myvip%.com/profile%.php%?act=getclubs&page=[0-9]+&uid="..item_value.."[0-9][0-9]$") and string.match(html, "list%-row%-card") then
      currentpage = string.match(url, "page=([0-9]+)")
      currentid = string.match(url, "uid=([0-9]+)")
      check("http://myvip.com/profile.php?act=getclubs&page=".. currentpage+1 .."&uid=".. currentid)
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if downloaded[url["url"]] == true then
    return wget.actions.EXIT
  end

  if abortproject == true then
    return wget.actions.ABORT
  end

  if string.match(url["url"], "^https?://[^/]*myvip%.com/ignore%.php%?uid=") then
    return wget.actions.EXIT
  end

  if string.match(url["url"], "^https?://[^/]*myvip%.com/index%.php$") then
    io.stdout:write("You lost your session cookies. ABORTING. Did you use the same account in two sessions?\n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if string.match(url["url"], "^https?://[^/]*myvip%.com/captcha%.php") and status_code == 302 then
    return wget.actions.EXIT
  end

  if (string.match(url["url"], "^https?://[^/]*myvip%.com/browse%.php%?act=browse&pager=") or string.match(url["url"], "^https?://[^/]*myvip%.com/browse%.php%?pager=")) and status_code ~= 200 then
    io.stdout:write("The server returned status code ".. status_code .." for URL "..url["url"]..". ABORTING.\n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
    io.stdout:write(item_dir..'/'..warc_file_base..'.txt'.."). Sleeping.\n")
    io.stdout:flush()
  local usersfile = io.open(item_dir..'/'..warc_file_base..'_data.txt', 'w')
  for url, _ in pairs(userpics) do
    usersfile:write(url.."\n")
  end
  usersfile:close()
end