# Development notes

This document is meant to help make sense of the code...

## sqlite database structure

The layout of the sqlite DB (zotero.db) is loosely based on the database of the Zotero desktop client.
When setting up its initial structure I copied across some of the tables and columns I thought would be needed and/or sounded useful.
Some columns are still not used, and others might now be used in a different way than in the desktop client (I did not really check...).

### 'libraries' table

[[CREATE TABLE IF NOT EXISTS libraries (
	libraryID INTEGER PRIMARY KEY,
	type TEXT NOT NULL,
	editable INT NOT NULL,
	name TEXT NOT NUll,
	userID INT NOT NULL DEFAULT 0,
	version INT NOT NULL DEFAULT 0,
	storageVersion INT NOT NULL DEFAULT 0,
	lastSync INT NOT NULL DEFAULT 0
);]]

Keeps track of the libraries contained in this database. When the database is first set up the plugin automatically creates one entry in this table.
This has `libraryID = 1` and is the user library (`type = "user"`). Currently the libraryID is hardcoded to this value (1), 
but if the code ever is extended to include group libraries this could be quite easily adapted...

Other columns used:
 1. name: name of the Zotero account
 2. userID: numerical userID needed to identify account and connect to API
 3. version: **keeps track of the Zotero library version**
 4. lastSync: unix timestamp for the last time the database was synced
 
The remaining columns are currently unused.

---
### 'collections' table

[[CREATE TABLE IF NOT EXISTS collections (    
	collectionID INTEGER PRIMARY KEY,
	collectionName TEXT NOT NULL,
	parentCollectionID INT DEFAULT NULL,
	libraryID INT NOT NULL,
	key TEXT NOT NULL,
	version INT NOT NULL DEFAULT 0,
	synced INT NOT NULL DEFAULT 0,
	UNIQUE (libraryID, key),
	FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE,
	FOREIGN KEY (parentCollectionID) REFERENCES collections(collectionID) ON DELETE CASCADE
);]]

Keeps track of the collections contained in this database.


---
### 'items' table

[[CREATE TABLE IF NOT EXISTS items (    
	itemID INTEGER PRIMARY KEY,    
	itemTypeID INT NOT NULL,    
	libraryID INT NOT NULL,    
	key TEXT NOT NULL,    
	version INT NOT NULL DEFAULT 0,    
	synced INT NOT NULL DEFAULT 0,    
	UNIQUE (libraryID, key),    
	FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
);]]

Keeps track of the main attributes of items (which all items have in common):
 1. itemID: primary key for item
 2. itemTypeID: 
 3. libraryID: identify the library this item belongs to
 4. key: text key as provided by Zotero API
 5.	version: version number 
 6. synced: ? **not used yet?**
 

---
### 'itemData' table

[[CREATE TABLE IF NOT EXISTS itemData (
	itemID INTEGER PRIMARY KEY,    
    value BLOB,
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE
);]]

Item information in the format returned by the Zotero API. 
`value` contains the JSON object for the item with `itemID`. 
To save some space the `library` and `links` fields are deleted first.
In principle only the `data` field would be all that is needed, but for now it also keeps `meta`.

**All items have entries in the items and itemData tables, but some will furthermore in some of the following tables:**

---
### 'collectionItems' table

[[CREATE TABLE IF NOT EXISTS collectionItems (
	collectionID INT NOT NULL,
	itemID INT NOT NULL,
	PRIMARY KEY(collectionID, itemID), 
	FOREIGN KEY (collectionID) REFERENCES collections(collectionID) ON DELETE CASCADE,
	FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE
);]]

If an item is part of a collection it will be included in this table.


---
### 'itemAttachments' table

[[CREATE TABLE IF NOT EXISTS itemAttachments ( 
	itemID INTEGER PRIMARY KEY, 
	parentItemID INT,
	syncedVersion INT NOT NULL DEFAULT 0,
	lastSync INT NOT NULL DEFAULT 0,
	FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
	FOREIGN KEY (parentItemID) REFERENCES items(itemID) ON DELETE CASCADE
);]]

If an item is a (supported) attachment then it will be included in this table.

---
### 'itemAttachments' table

[[CREATE TABLE IF NOT EXISTS itemAnnotations ( 
	itemID INTEGER PRIMARY KEY, 
	parentItemID INT,
	syncedVersion INT NOT NULL DEFAULT 0,
	FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
	FOREIGN KEY (parentItemID) REFERENCES items(itemID) ON DELETE CASCADE
);
]]

If an item is a (supported) annotation then it will be included in this table.

---
### 'itemTypes' table

[[CREATE TABLE IF NOT EXISTS itemTypes ( 
	itemTypeID INTEGER PRIMARY KEY, 
	typeName TEXT, 
	display INT DEFAULT 1 
);]]

This table is pre-populated with all the different Zotero item types when the databse is first set up.