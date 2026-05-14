local Dispatcher = require("dispatcher") -- luacheck:ignore
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local DataStorage = require("datastorage")
-- local Screen = Device.screen
-- local Device = require("device")
local Font = require("ui/font")
local Menu = require("ui/widget/menu")
-- local Geom = require("ui/geometry")
local _ = require("gettext")
local ZoteroBrowser = require("zoterobrowser")
-- local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
--local NetworkMgr = require("ui/network/manager")
-- local DocSettings = require("docsettings")
local LuaSettings = require("luasettings")
local Trapper = require("frontend/ui/trapper")

local DEFAULT_LINES_PER_PAGE = 14

local default_settings = {
    ["items_per_page"] = DEFAULT_LINES_PER_PAGE,
    ["auto_disable_pdf_writing"] = true,
    ["annotation_default_color"] = "gray",
    ["debug_level"] = 2,
}
--local init_done = false

local Plugin = WidgetContainer:extend{
    name = "zotero",
    settings_file = DataStorage:getSettingsDir() .. "/zotero.lua",
    settings = nil,
    zotero_account = nil,
    webdav = nil,
    is_doc_only = false,
}

function Plugin:onDispatcherRegisterActions()
    Dispatcher:registerAction("zotero_browser_action", {
        category = "none",
        event = "ZoteroBrowserAction",
        title = _("Zotero Collection Browser"),
        general = true,
    })
    -- Dispatcher:registerAction("zotero_sync_action", {
    --     category = "none",
    --     event = "ZoteroSyncAction",
    --     title = _("Zotero Sync"),
    --     general = true,
    -- })
end

function Plugin:init()
    -- not sure when this is called, so I don't understand why some bits need to be
    -- re-initialised every time.
    -- But at least the ZoteroAPI only needs to be initialised once
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    --self.initialized = init_done
    logger.info("Zotero: Plugin init executed!")
end

-- function Plugin:checkInitialized()
--     if not self.initialized or self.browser == nil then
--         UIManager:show(InfoMessage:new({
--             text = _("Zotero not initialized. Please set the plugin directory first."),
--             timeout = 3,
--             icon = "notice-warning",
--         }))
--     end

--     return self.initialized
-- end

function Plugin:loadSettings()
    if self.settings then return end
    self.settings = LuaSettings:open(self.settings_file)
    if next(self.settings.data) == nil then
        self.updated = true -- first run, force flush
    end
    self.zotero_account = self.settings:readSetting("zotero", {})
    self.webdav = self.settings:readSetting("webdav", {})
    self.zotero_settings = self.settings:readSetting("settings", default_settings)
    if self.updated then    -- see if there is an old style settings file. If so, take data
        local BaseUtil = require("ffi/util")
        local old_settings_path = BaseUtil.joinPath(BaseUtil.joinPath(DataStorage:getDataDir(), "zotero"), "meta.lua")
        local old_settings = LuaSettings:open(old_settings_path)
        if next(old_settings.data) ~= nil then
            if old_settings:readSetting("user_id") then
                self.zotero_account.user_id = old_settings:readSetting("user_id")
            end
            if old_settings:readSetting("api_key") then
                self.zotero_account.api_key = old_settings:readSetting("api_key")
            end
            if old_settings:readSetting("webdav_url") then
                self.webdav.url = old_settings:readSetting("webdav_url")
            end
            if old_settings:readSetting("webdav_user") then
                self.webdav.user_id = old_settings:readSetting("webdav_user")
            end
            if old_settings:readSetting("webdav_password") then
                self.webdav.password = old_settings:readSetting("webdav_password")
            end
            if old_settings:readSetting("webdav_enabled") then
                self.webdav.enabled = old_settings:readSetting("webdav_enabled")
            end
        end
    end
end

function Plugin:addToMainMenu(menu_items)
    menu_items.zotero = {
        text = _("Zotero"),
        sorting_hint = "search",
        callback = function()
            self:onZoteroBrowserAction()
        end,        
    }
end

function Plugin:onZoteroBrowserAction()
    self.small_font_face = Font:getFace("smallffont")
    self:loadSettings()
    if not self.browser then
        self.browser = ZoteroBrowser:new({
            -- dir_path = self.zotero_dir_path,
            settings = self.zotero_settings,
            zotero_account = self.zotero_account,
            webdav = self.webdav,
            _manager = self,
            items_per_page = self.zotero_settings.items_per_page,
            is_popout = false,
            is_borderless = true,
            title_bar_fm_style = true,
            close_callback = function()
                --UIManager:close(self.browser)
                --self.browser = nil
            end,
        })
        self.browser:initAPI()
        logger.info("Zotero: Browser initialized")
    end
    UIManager:show(self.browser)
    self.browser:displayCollection(nil)
end

-- function Plugin:onZoteroSyncAction()
--     if not self:checkInitialized() then
--         return
--     end
--     NetworkMgr:runWhenOnline(function()
--         Trapper:wrap(function()
--             Trapper:info("Synchronizing Zotero library.")
--             local e = ZoteroAPI.syncAllItems(function(msg)
--                 Trapper:info(msg)
--             end)

--             if e == nil then
--                 Trapper:info("Success")
--             else
--                 Trapper:info(e)
--             end
--         end)
--     end)
-- end

-- This automatically gets called when the plugin is closed down (typically when KOReader exits)
function Plugin:onFlushSettings()
    if self.updated then
        self.settings:flush()
        self.updated = nil
    end
end

return Plugin
