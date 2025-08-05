var FSLibrary = {
    js_syncfs: function () {
        FS.syncfs(false, function (err) {
            if (err) {
                console.error("Sync failed:", err);
            }
        });
    },
};

mergeInto(LibraryManager.library, FSLibrary);
