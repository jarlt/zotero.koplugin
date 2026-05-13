local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher") -- luacheck:ignore
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local DataStorage = require("datastorage")
local FrameContainer = require("ui/widget/container/framecontainer")
local Device = require("device")
local Screen = Device.screen
local Font = require("ui/font")
local Menu = require("ui/widget/menu")
local Geom = require("ui/geometry")
local _ = require("gettext")
local ZoteroAPI = require("zoteroapi")
local itemInfoViewer = require("zoteroiteminfo")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local CheckButton = require("ui/widget/checkbutton")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local NetworkMgr = require("ui/network/manager")
local DocSettings = require("docsettings")
--local LuaSettings = require("luasettings")
local Trapper = require("frontend/ui/trapper")

local DEFAULT_LINES_PER_PAGE = 14

local table_empty = function(table)
    -- see https://stackoverflow.com/a/1252776
    local next = next
    return (next(table) == nil)
end

local sortTextDes = function(a, b)
    return a.text > b.text
end

local sortTextAsc = function(a, b)
    return a.text < b.text
end


local ZoteroBrowser = Menu:extend({
    no_title = false,
    is_borderless = true,
    is_popout = false,
    show_path = true,
    --    subtitle = "test path",
    title_bar_fm_style = true,
    parent = nil,
    covers_full_screen = true,
    return_arrow_propagation = false,
    -- Slightly ugly using the option below, but better than truncated single line:
    multilines_show_more_text = true,
})

function ZoteroBrowser:init()
    self.title_bar_left_icon = "appbar.menu"
    self.paths = {}
    self.keys = {}
    Menu.init(self)  -- call parent's init()
end

function ZoteroBrowser:initAPI()
    self.sorting = sortTextAsc
    self.sort_ascend = true
    self.dir_path = DataStorage:getDataDir() .. "/zotero"
    lfs.mkdir(self.dir_path)
    ZoteroAPI.init(self.dir_path, self.zotero_account, self.webdav, self.settings)
end


-- Show search input
function ZoteroBrowser:onLeftButtonTap()
    local dialog
    dialog = ButtonDialog:new{
        buttons = {
            {{
                    text = _("Search library"), --"\u{f002} " .. _("Search library"),
                    callback = function()
                        UIManager:close(dialog)
                        self:searchDialog()
                    end,
                    align = "left",
            }},
            {},
            {{
                    text = _("Sync library"), --"\u{f46a} " .. _("Sync library"),
                    callback = function()
                        UIManager:close(dialog)
                        NetworkMgr:runWhenConnected(function()
                            self:sync()
                        end)
                    end,
                    align = "left",
            }},
            {{
                    text = _("Sorting"), 
                    callback = function()
                        UIManager:close(dialog)
                        if self.sort_ascend then
                            self.sorting = sortTextDes
                        else
                            self.sorting = sortTextAsc 
                        end
                        self.sort_ascend = not self.sort_ascend
                    end,
                    align = "left",
            }},
--[[             {{
                    text = _("Reload root"),
                    callback = function()
                        UIManager:close(dialog)
                        self.paths = {}
                        self.keys = {}
                        self:displayCollection(nil)
                    end,
                    align = "left",
            }},
            {{
                    text = _("Zotero config"),
                    callback = function()
                        self:setAccount()
                    end,
                    align = "left",
            }},
            {{
                    text = _("Webdav config"),
                    callback = function()
                        self:webDavDialog()
                    end,
                    align = "left",
            }},
]]            {{
                    text = _("Maintenance"), --"\u{f067} " .. _("Maintenance"),
                    callback = function()
                        UIManager:close(dialog)
                        self:maintenanceDialog()
                    end,
                    align = "left",
            }},
            {{
                    text = _("Settings"), --"\u{f067} " .. _("Settings"),  -- should find better icon
                    callback = function()
                        UIManager:close(dialog)
                        self:settingsDialog()
                    end,
                    align = "left",
            }},
            {{
                    text = _("About"),
                    callback = function()
                        UIManager:close(dialog)
                        self:showAbout()
                    end,
                    align = "left",
            }},            
        },
        shrink_unneeded_width = true,
        anchor = function()
            return self.title_bar.left_button.image.dimen
        end,
    }
    UIManager:show(dialog)
end

function ZoteroBrowser:settingsDialog()
    local settingsDialog
    settingsDialog = ButtonDialog:new{
        buttons = {
            {{
                text = _("Zotero configuration"),
                callback = function()
                    UIManager:close(settingsDialog)
                    self:setAccount()
                end,
            }},
            {{
                text = _("WebDAV configuration"),
                callback = function()
                    UIManager:close(settingsDialog)
                    self:webDavDialog()
                end,
            }},                        
            {{
                text = _("Other settings"),
                callback = function()
                    UIManager:close(settingsDialog)
                    self:miscDialog()
                end,
            }},                   
        },
        --shrink_unneeded_width = true,
    }
    UIManager:show(settingsDialog)
end

function ZoteroBrowser:miscDialog()
    local settingsDialog
    settingsDialog = ButtonDialog:new{
        buttons = {
            {{
                text = _("Set items per page"),
                callback = function()
                    UIManager:close(settingsDialog)
                    self:setItemsPerPage()
                end,
            }},
            {{
                text = _("Annotation default color"),
                enabled = false, -- as it is not implemented yet
                callback = function()
                    UIManager:close(settingsDialog)
                    -- TO-DO
                end,
            }},                           
            {{
                text = _("Auto-disable PDF annotation writing") .. (self.settings.auto_disable_pdf_writing and "  ✓" or ""),
                callback = function()
                    UIManager:close(settingsDialog)
                    self.settings.auto_disable_pdf_writing = not self.settings.auto_disable_pdf_writing
                    self._manager.updated = true
                end,
            }}, 
            {{
                text = _("Set debug level"),
                callback = function()
                    assert(self.settings ~= nil)
                    self.debug_dialog = SpinWidget:new({
                        title_text = _("Set debug level"),
                        value = self.settings.debug_level or 0,
                        value_min = 0,
                        value_max = 5,
                        callback = function(d)
                            self.settings.debug_level = d.value
                            ZoteroAPI.setDebugLevel(d.value)
                            self._manager.updated = true
                        end,
                    })
                    UIManager:show(self.debug_dialog)
                end,
            }}                          
        },
        --shrink_unneeded_width = true,
    }
    UIManager:show(settingsDialog)
end

function ZoteroBrowser:setItemsPerPage()
    assert(self.settings ~= nil)
    self.items_per_page_dialog = SpinWidget:new({
        title_text = _("Set items per page"),
        value = self.settings.items_per_page or DEFAULT_LINES_PER_PAGE,
        value_min = 1,
        value_max = 30,
        callback = function(d)
            self.settings.items_per_page = d.value
            self._manager.updated = true
            UIManager:show(InfoMessage:new({
                text = _("This change requires a restart of the Zotero browser."),
                timeout = 3,
                icon = "notice",
            }))
        end,
    })
    UIManager:show(self.items_per_page_dialog)
end


function ZoteroBrowser:maintenanceDialog()
    local maintenanceDialog
    maintenanceDialog = ButtonDialog:new{
        buttons = {
            {{
                text = _("Re-analyse local items"),
                callback = function()
                    UIManager:close(maintenanceDialog)
                    Trapper:wrap(function()
                        Trapper:info("Re-checking items in local Zotero database.")
                        local e = ZoteroAPI.checkItemData(function(msg)
                            Trapper:info(msg)
                        end)

                        if e == nil then
                            Trapper:info("Success")
                        else
                            Trapper:info(e)
                        end
                    end)
                end,
            }},
            {{
                text = _("Re-scan storage for local items"),
                callback = function()
                    UIManager:close(maintenanceDialog)
                    Trapper:wrap(function()
                        Trapper:info("Scanning local Zotero storage.")
                        local cnt = ZoteroAPI.scanStorage()

                        Trapper:info("Found " .. cnt .. " local attachments.")
                    end)
                end,
            }},
            {{
                text = _("Re-download Zotero library"),
                callback = function()
                    UIManager:close(maintenanceDialog)
                    ZoteroAPI.resetSyncState()
                    NetworkMgr:runWhenOnline(function()
                        Trapper:wrap(function()
                            Trapper:info("Resynchronizing Zotero library.")
                            local e = ZoteroAPI.syncAllItems(function(msg)
                                Trapper:info(msg)
                            end)

                            if e == nil then
                                Trapper:info("Success")
                            else
                                Trapper:info(e)
                            end
                        end)
                    end)
                end,
            }},                     
        },
        shrink_unneeded_width = true,
    }
    UIManager:show(maintenanceDialog)
end

-- Shows dialog to edit properties of the new/existing catalog
function ZoteroBrowser:webDavDialog()
    local fields = {
        {
            text = self.webdav.url,
            hint = _("URL"),
        },
        {
            text = self.webdav.user_id,
            hint = _("Username"),
        },
        {
            text = self.webdav.password,
            hint = _("Password"),
        },
    }

    local dialog, check_button_enable
    dialog = MultiInputDialog:new{
        title = _("WebDAV configuration"),
        fields = fields,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Test"),
                    id = "test",
                    callback = function()
                        -- to do
                        local new_fields = dialog:getFields()                        
                        self.webdav.url = new_fields[1]
                        self.webdav.user_id = new_fields[2]
                        self.webdav.password = new_fields[3]
                        NetworkMgr:runWhenOnline(function()
                            local msg = nil
                            local result = ZoteroAPI.checkWebDAV()
                            if result == nil then
                                msg = _("Success, WebDAV works!")
                            else
                                msg = _("WebDAV could not connect: ") .. result
                            end
                            UIManager:show(InfoMessage:new({
                                text = msg,
                                timeout = 5,
                                icon = "notice-info",
                            }))
                        end)

                    end,
                },
                {
                    text = _("Save"),
                    callback = function()
                        local new_fields = dialog:getFields()                        
                        self.webdav.url = new_fields[1]
                        self.webdav.user_id = new_fields[2]
                        self.webdav.password = new_fields[3]
                        self.webdav.enabled = check_button_enable.checked or false
                        self._manager.updated = true
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    check_button_enable = CheckButton:new{
        text = _("Enable WebDav"),
        checked = self.webdav.enabled,
        parent = dialog,
    }
    dialog:addWidget(check_button_enable)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function ZoteroBrowser:showAbout()
    local version = ZoteroAPI.version
    local stats = ZoteroAPI.getStats()
    local auto_disable_status = (self.settings.auto_disable_pdf_writing or true)
        and "Enabled"
        or "Disabled"
    UIManager:show(InfoMessage:new({
        text = _(
            "Plugin version: \n"
            .. version
            .. "\n\nLibrary info:\n  Name:\t\t"
            .. stats.name
            .. "\n  Version:\t"
            .. stats.libVersion
            .. "\n  Last sync: "
            .. stats.lastSync
            .. "\n\nLibrary stats:\n\tCollections:\t\t"
            .. stats.collections
            .. "\n\tTotal items:\t\t"
            .. stats.items
            .. "\n\tAttachments:\t"
            .. stats.attachments
            .. "\n\tAnnotations:\t"
            .. stats.annotations
            .. "\n\tCreators:\t\t"
            .. stats.creators
            .. "\n\tPublications:\t"
            .. stats.publications
            .. "\n\tTags:\t\t"
            .. stats.tags
            .. "\n\nPDF Settings:\n\tAuto-disable PDF writing:\t"
            .. auto_disable_status
            .. "\n"
        ),
        --timeout = 10,
        --icon = "notice"
        show_icon = false,
    }))
end

-- Show search input
function ZoteroBrowser:searchDialog()
    local search_query_dialog
    search_query_dialog = InputDialog:new({
        title = _("Search Zotero titles"),
        input = "",
        input_hint = "search query",
        description = _("This will search title and first author of all entries."),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(search_query_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        UIManager:close(search_query_dialog)
                        self:displaySearchResults(search_query_dialog:getInputText())
                    end,
                },
            },
        },
    })
    UIManager:show(search_query_dialog)
    search_query_dialog:onShowKeyboard()
end

function ZoteroBrowser:setAccount()
    self.account_dialog = MultiInputDialog:new({
        title = _("Edit Zotero account settings"),
        fields = {
            {
                text = self.zotero_account.user_id,
                hint = _("User ID (integer)"),
            },
            {
                text = self.zotero_account.api_key,
                hint = _("API Key"),
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        self.account_dialog:onClose()
                        UIManager:close(self.account_dialog)
                    end,
                },
                {
                    text = _("Update"),
                    callback = function()
                        local fields = self.account_dialog:getFields()
                        if not string.match(fields[1], "[0-9]+") then
                            UIManager:show(InfoMessage:new({
                                text = _("The User ID must be an integer number."),
                                timeout = 3,
                                icon = "notice-warning",
                            }))
                            return
                        end

                        self.zotero_account.user_id = fields[1]
                        self.zotero_account.api_key = fields[2]
                        ZoteroAPI.zoteroAcessVerified = false
                        self._manager.updated = true
                        self.account_dialog:onClose()
                        UIManager:close(self.account_dialog)
                    end,
                },
            },
        },
    })
    UIManager:show(self.account_dialog)
    self.account_dialog:onShowKeyboard()
end

function ZoteroBrowser:sync()
    Trapper:wrap(function()
        Trapper:info("Synchronizing Zotero library.")
        local e = ZoteroAPI.syncAllItems(function(msg)
            Trapper:info(msg)
        end)

        if e == nil then
            Trapper:info("Success")
                -- maybe nicer to stay in the folder we were in when starting sync, but this is easiest to implement...
                self.paths = {}
                self.keys = {}
                self:displayCollection(nil)
        else
            Trapper:info(e)
        end
    end)
end


function ZoteroBrowser:onReturn()
	local path = table.remove(self.paths, #self.paths)
    local key = table.remove(self.keys, #self.keys)
    local itemmatch = { ["key"] = key }
    if #self.keys == 0 then
        self:displayCollection(nil, itemmatch)
    elseif key == "tag" then
		itemmatch = { ["text"] = path }
		self:displayTags(itemmatch)
    elseif key == "creator" then
		itemmatch = { ["text"] = path }
		self:displayCreators(itemmatch)
    else
        self:displayCollection(self.keys[#self.keys], itemmatch)
    end
    return true
end

-- Function to disable PDF annotation writing for Zotero files
function ZoteroBrowser:disablePDFannotions(file_path)
    if file_path and file_path:match("%.pdf$") then
        -- Check if auto-disable setting is enabled
        local auto_disable = self.settings.auto_disable_pdf_writing or true
        if auto_disable then
            local doc_settings = DocSettings:open(file_path)
            doc_settings:saveSetting("highlight_write_into_pdf", false)
            doc_settings:flush()
            logger.info("Zotero: Disabled PDF annotation writing for Zotero document: " .. file_path)
        end
    end
end


function ZoteroBrowser:openAttachment(key)
	local item, fileStatus, e = ZoteroAPI.checkAttachmentStatus(key)
	local targetDir, full_path
    if e ~= nil or item == nil then
		local b = InfoMessage:new({
			text = _("Could not open file. ") .. e,
			timeout = 5,
			icon = "notice-warning",
		})
		UIManager:show(b)
	else
        targetDir, full_path = ZoteroAPI.getDirAndPath(item)
        if fileStatus < 2 then  -- file needs downloading
            NetworkMgr:runWhenOnline(function()
                local full_path, e = ZoteroAPI.downloadAttachment(item, full_path)
                if e ~= nil or full_path == nil then
                    local b = InfoMessage:new({
                        text = _("Could not download file. ") .. e,
                        timeout = 5,
                        icon = "notice-warning",
                    })
                    UIManager:show(b)
                end
            end)
        else
            -- Check whether there are any annotations that need to be attached and save library version to sdr file
            ZoteroAPI.attachItemAnnotations(item)
        end
    end
    --logger.info("Zotero:openAttachment path: " .. full_path)
	if full_path and lfs.attributes(full_path) then 
		UIManager:close(self.download_dialog)
		self:disablePDFannotions(full_path)
        if self._manager.ui.document then
            self._manager.ui:switchDocument(full_path)
        else
            self._manager.ui:openFile(full_path)
        end
	    --local ReaderUI = require("apps/reader/readerui")
		self.close_callback()
		--ReaderUI:showReader(full_path)
	end
end

function ZoteroBrowser:onMenuSelect(item)
    if item.type == "collection" then
        table.insert(self.paths, item.text)
        table.insert(self.keys, item.key)
        self:displayCollection(item.key)
    elseif item.type == "wildcard_collection"  then
        --table.insert(self.paths, "All items")
        --table.insert(self.keys, "all")
        self:displaySearchResults("")
    elseif item.type == "tag_collection"  then
		table.insert(self.paths, "Tags/")
		table.insert(self.keys, "tagList")
		self:displayTags()
    elseif item.type == "creator_collection"  then
		table.insert(self.paths, "Authors/")
		table.insert(self.keys, "authorList")
		self:displayCreators()
    elseif item.type == "publications"  then
		table.insert(self.paths, "My Publications/")
		table.insert(self.keys, "publications")
		self:displayMyPublications()
    elseif item.type == "tag"  then
        self:displayTaggedItems(item.text)
    elseif item.type == "creator"  then
        self:displayCreatorItems(item.text, item.id)
    elseif item.type == "item" then
        self.download_dialog = InfoMessage:new({
            text = _("Downloading file"),
            timeout = 5,
            icon = "notice-info",
        })
        UIManager:scheduleIn(0.05, function()
                local attachments = ZoteroAPI.getItemAttachments(item.key)
                if attachments == nil or table_empty(attachments) then
                    local b = InfoMessage:new({
                        text = _("The selected entry does not have any attachments."),
                        timeout = 5,
                        icon = "notice-warning",
                    })
                    UIManager:show(b)
                    return
                else
                    -- Try to find and open a PDF attachment first
                    local pdf_attachment = nil
                    for _, attachment in ipairs(attachments) do
                        if attachment.contentType == "application/pdf" or
                            (attachment.filename and attachment.filename:match("%.pdf$")) then
                            pdf_attachment = attachment
                            break
                        end
                    end

                    -- Open PDF if found, otherwise fall back to last attachment
                    if pdf_attachment then
                        self:openAttachment(pdf_attachment.key)
                    else
                        self:openAttachment(attachments[#attachments].key)
                    end
                end
        end)
        UIManager:show(self.download_dialog)
    elseif item.type == "attachment" then
        self:openAttachment(item.key)
    elseif item.type == "label" then
        -- nop
    end
end

function ZoteroBrowser:onMenuHold(item)
    if item.type == "item" then
        --table.insert(self.paths, item.key)
        --table.insert(self.keys, item.key)
        --self:displayAttachments(item.key)
        local itemDetails = ZoteroAPI.getItemWithAttachments(item.key)
        local itemInfo = itemInfoViewer:new()
        itemInfo:show(itemDetails, function(key)
            self:openAttachment(key)
        end)
    elseif item.type == "collection" then
        local is_offline_enabled = ZoteroAPI.isOfflineCollection(item.key)
        local button_label = "▢  Download this collection during sync"
        if is_offline_enabled then
            button_label = "✓ Download this collection during sync"
        end
        local collection_dialog
        collection_dialog = ButtonDialog:new({
            title = item.text,
            buttons = {
                {
                    {
                        text = button_label,
                        callback = function()
                            if is_offline_enabled then
                                ZoteroAPI.removeOfflineCollection(item.key)
                            else
                                ZoteroAPI.addOfflineCollection(item.key)
                            end
                            UIManager:close(collection_dialog)
                        end,
                    },
                },
            },
        })
        UIManager:show(collection_dialog)
    end
end

function ZoteroBrowser:displaySearchResults(query)
    local items = ZoteroAPI.displaySearchResults(query)
    table.insert(self.paths, query)
    table.insert(self.keys, "search")
    items = self:addLabelIfEmpty(items, "No search results!")
    table.sort(items, self.sorting)
    self:setItems(items)
end

function ZoteroBrowser:displayTags(itemmatch)
    local items = ZoteroAPI.getTags()
    self:setItems(items, itemmatch)
end

function ZoteroBrowser:displayTaggedItems(tag)
    local items = ZoteroAPI.getTaggedItems(tag)
	table.insert(self.paths, tag)
    table.insert(self.keys, "tag")
    --print(items[1].text)
    self:setItems(items)
end

function ZoteroBrowser:displayCreators(itemmatch)
    local items = ZoteroAPI.getCreators()
    self:setItems(items, itemmatch)
end

function ZoteroBrowser:displayCreatorItems(creator, cID)
    local items = ZoteroAPI.getCreatorItems(cID)
	table.insert(self.paths, creator)
    table.insert(self.keys, "creator")
    self:setItems(items)
end


function ZoteroBrowser:displayMyPublications()
    local items = ZoteroAPI.getMyPublications()
    --print(items[1].text)
    self:setItems(items)
end

function ZoteroBrowser:displayCollection(collection_id, itemmatch)
    local collections, items = ZoteroAPI.displayCollection(collection_id)

    if collection_id == nil then
		if table_empty(items) and table_empty(collections) then
			items = self:addLabelIfEmpty(items, "Local library is empty! Synchronise first...")
		else
            local stats = ZoteroAPI.getStats()
			table.insert(collections, 1, {
				["text"] = _("All Items"),
				["type"] = "wildcard_collection"
			})
            if stats.creators > 0 then
				table.insert(collections, 2, {
					["text"] = _("Authors"),
					["type"] = "creator_collection",
					["bold"] = true,
					["mandatory"] = stats.creators,
				})
            end
			if stats.tags > 0 then
				table.insert(collections, 2, {
					["text"] = _("Tags"),
					["type"] = "tag_collection",
					["bold"] = true,
					["mandatory"] = stats.tags,
				})
			end
			if stats.publications > 0 then
				table.insert(collections, 2, {
					["text"] = _("My Publications"),
					["type"] = "publications",
					["bold"] = true,
					["mandatory"] = stats.publications,
				})
			end
		end
	elseif table_empty(collections) then
	    items = self:addLabelIfEmpty(items)
	end

    table.sort(items,  self.sorting)

    table.move(items, 1, #items, #collections + 1, collections)
    self:setItems(collections, itemmatch)
end

function ZoteroBrowser:addLabelIfEmpty(items, msg)
    if table_empty(items) then
        if msg == nil then
            msg = "No Items"
        end
        table.insert(items, 1, {
            ["text"] = _(msg),
            ["type"] = "label",
        })
    end

    return items
end

function ZoteroBrowser:displayAttachments(key)
    local attachments = ZoteroAPI.getItemAttachments(key) or {}
    attachments = self:addLabelIfEmpty(attachments)

    self:setItems(attachments)
end

function ZoteroBrowser:zPath()
    local path = "HOME"
    if #self.paths > 0 then
        if self.keys[#self.keys] == "search" then
            path = "Search results: '" .. self.paths[#self.paths] .. "'"
        else
            path = "/" .. table.concat(self.paths, "")
        end
    end
    return path
end

function ZoteroBrowser:setItems(items, itemmatch)
	local subtitle = self:zPath()
	--[[
	if itemmatch ~= nil then
		local key, value = next(itemmatch)
		print(key, value)
	end
	--]]
    self:switchItemTable("Zotero Browser", items, nil, itemmatch, subtitle)
end

return ZoteroBrowser