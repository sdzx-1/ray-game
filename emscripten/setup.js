Module["preRun"] = Module["preRun"] || [];
Module["preRun"].push(function () {
    Module.addRunDependency("idbfs-sync");

    FS.mkdir("/save-data");
    FS.mount(IDBFS, {}, "/save-data");

    FS.syncfs(true, function (err) {
        if (err) {
            console.error("Failed to load persistent data:", err);
        }
        Module.removeRunDependency("idbfs-sync");
    });
});
