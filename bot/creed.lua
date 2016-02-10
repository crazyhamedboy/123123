package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    ".",
    "Feedback",
    "plugins",
    "lock_join",
    "antilink",
    "antitag",
    "gps",
    "auto_leave",
    "cpu",
    "calc",
    "bin",
    "tagall",
    "text",
    "info",
    "bot_on_off",
    "welcome",
    "His",
    "webshot",
    "google",
    "sms",
    "anti_spam",
    "add_bot",
    "owners",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {172178919},--Sudo users
    disabled_chann144152859els = {},
    realm = {},--Realms Id
    moderation = {data = 'data/moderation.json'},
    about_text = [[Creed bot 2.3
    
     Hello my Good friends 
     
    ?? this bot is made by : @creed_is_dead
   ????????
   ??   our admins are : 
   ??   @amirmr33   ????????
  ?? You can send your Ideas and messages to Us By sending them into bots account by this command :
   تمامي درخواست ها و همه ي انتقادات و حرفاتونو با دستور زير بفرستين به ما
   !feedback (your ideas and messages)
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group
گروه جديدي بسازيد

!createrealm [Name]
Create a realm
گروه مادر جديدي بسازيد

!setname [Name]
Set realm name
اسم گروه مادر را تغيير بدهيد

!setabout [GroupID] [Text]
Set a group's about text
در مورد  آن گروه توضيحاتي را بنويسيد (اي دي گروه را بدهيد )

!setrules [GroupID] [Text]
Set a group's rules
در مورد آن گروه قوانيني تعيين کنيد ( اي دي گروه را بدهيد )

!lock [GroupID] [setting]
Lock a group's setting
تنظيکات گروهي را قفل بکنيد

!unlock [GroupID] [setting]
Unock a group's setting
تنظيمات گروهي را از قفل در بياوريد 

!wholist
Get a list of members in group/realm
ليست تمامي اعضاي گروه رو با اي دي شون نشون ميده

!who
Get a file of members in group/realm
ليست تمامي اعضاي گروه را با اي دي در فايل متني دريافت کنيد

!type
Get group type
در مورد نقش گروه بگيريد

!kill chat [GroupID]
Kick all memebers and delete group ????
??تمامي اعضاي گروه را حذف ميکند ??

!kill realm [RealmID]
Kick all members and delete realm????
تمامي اعضاي گروه مارد را حذف ميکند

!addadmin [id|username]
Promote an admin by id OR username *Sudo only
ادميني را اضافه بکنيد


!removeadmin [id|username]
Demote an admin by id OR username *Sudo only????
????ادميني را با اين دستور صلب مقام ميکنيد ????

!list groups
Get a list of all groups
ليست تمامي گروه هارو ميده

!list realms
Get a list of all realms
ليست گروه هاي مادر را ميدهد


!log
Get a logfile of current group or realm
تمامي عمليات گروه را ميدهد

!broadcast [text]
Send text to all groups ??
?? با اين دستور به تمامي گروه ها متني را همزمان ميفرستيد  .

!br [group_id] [text]
This command will send text to [group_id]??
با اين دستور ميتونيد به گروه توسط ربات متني را بفرستيد 

You Can user both "!" & "/" for them
ميتوانيد از هردوي کاراکتر هاي ! و / براي دستورات استفاده کنيد


]],
    help_text = [[
Creed bots Help for mods : Plugins

Shayan123 : 


Help For Banhammer دستوراتي براي کنترل گروه

!Kick @UserName or ID 
شخصي را از گروه حذف کنيد . همچنين با ريپلي هم ميشه

!Ban @UserName or ID
براي بن کردن شخص اسفاده ميشود . با ريپلي هم ميشه


!Unban @UserName
براي آنبن کردن شخصي استفاده ميشود . همچنين با ريپلي هم ميشه

For Admins :

!banall ID
براي بن گلوبال کردن از تمامي گروه هاست بايد اي دي بدين با ريپلي هم ميشه

!unbanall ID
براي آنبن کردن استفاده ميشود ولي فقط با اي دي ميشود

??????????
2. GroupManager :

!lock leave
اگر کسي از گروه برود نميتواند برگردد

!lock tag
براي مجوز ندادن به اعضا از استفاده کردن @  و #  براي تگ


!Creategp "GroupName"
you can Create group with this comman
با اين دستور براي ساخت گروه استفاده بکنيد


!lock member
For locking Inviting users
براي جلوگيري از آمدن اعضاي جديد استفاده ميشود


!lock bots
for Locking Bots invitation
براي جلوگيري از ادد کردن ربا استفاده ميشود


!lock name ??
To lock the group name for every bodey
براي قفل کردن اسم استفاده ميشود
!setflood??et the group flood control???زان اسپم را در گروه تعيين ميکنيد

!settings ?
Watch group settings
تنظيمات فعلي گروه را ميبينيد

!owner
watch group owner
آيدي سازنده گروه رو ميبينيد

!setowner user_id??
You can set someone to the group owner??
براي گروه سازنده تعيين ميکنيد 

!modlist
catch Group mods
ليست مديران گروه را ميگيريد

!lock join 
to lock joining the group by link
براي جلوگيري از وارد شدن به کروه با لينک


!lock flood??
lock group flood
از اسپم دادن در گروه جلوگيري کنيد

!unlock (bots-member-flood-photo-name-tag-link-join-Arabic)?
Unlock Something
موارد بالا را با اين دستور آزاد ميسازيد

!rules  && !set rules
TO see group rules or set rules
براي ديدن قوانين گروه و يا انتخاب قوانين 

!about or !set about
watch about group or set about
در مورد توضيحات گروه ميدهد و يا توضيحات گروه رو تعيين کنيد 

!res @username
see Username INfo
در مورد اسم و اي دي شخص بهتون ميده 

!who??
Get Ids Chat
امي اي دي هاي موجود در چت رو بهتون ميده

!log 
get members id ??
تمامي فعاليت هاي انجام يافته توسط شما و يا مديران رو نشون ميده

!all
Says every thing he knows about a group
در مورد تمامي اطلاعات ثبت شده در مورد گروه ميدهد


!newlink
Changes or Makes new group link
لينک گروه رو عوض ميکنه 

!getlink
gets The Group link
لينک گروه را در گروه نمايش ميده

!linkpv
sends the group link to the PV
براي دريافت لينک در پيوي استفاده ميشه 
????????
Admins :®
!add
to add the group as knows
براي مجوز دادن به ربات براي استفاده در گروه


!rem
to remove the group and be unknown
براي ناشناس کردن گروه براي ربات توسط مديران اصلي

!setgpowner (Gpid) user_id ??
For Set a Owner of group from realm
 براي تعيين سازنده اي براي گروه  از گروه مادر

!addadmin [Username]
to add a Global admin to the bot
براي ادد کردن ادمين اصلي ربات


!removeadmin [username]
to remove an admin from global admins
براي صلب ادميني از ادميناي اصلي


!plugins - [plugins]
To Disable the plugin
براي غير فعال کردن پلاگين توسط سازنده


!plugins + [plugins]
To enable a plugins
براي فعال کردن چلاگين توسط سازنده

!plugins ?
To reload al plugins
راي تازه سازي تمامي پلاگين هاي فعال

!plugins
Shows the list of all plugins
ليست تمامي پلاگين هارو نشون ميده

!sms [id] (text)
To send a message to an account by his/her ID
براي فرستادن متني توسط ربات به شخصي با اي دي اون


???????????
3. Stats :©
!stats creedbot (sudoers)??
To see the stats of creed bot
براي ديدن آمار ربات 

!stats
To see the group stats
براي ديدن آمار گروه 

????????
4. Feedback??
!feedback (text)
To send your ideas to the Moderation group
براي فرستادن انتقادات و پيشنهادات و حرف خود با مدير ها استفاده ميشه

???????????
5. Tagall??
!tagall (text)
To tags the every one and sends your message at bottom
تگ کردن همه ي اعضاي گروه و نوشتن پيام شما زيرش

?????????
More plugins  soon ...
?? We are Creeds ??

our channel : @creedantispam_channel
کانال ما

You Can user both "!" & "/" for them
مي توانيد از دو شکلک !  و / براي دادن دستورات استفاده کنيد

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
