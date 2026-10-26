import Toybox.Lang;

function ciqManifestEntries(data as Dictionary) as Array<Dictionary>? {
    if (data["complete"] != true || !(data["entries"] instanceof Array)) { return null; }
    var raw=data["entries"] as Array;
    if (raw.size()>30) { return null; }
    var result=[] as Array<Dictionary>; var seen={} as Dictionary; var names={} as Dictionary;
    for (var index=0;index<raw.size();index++) {
        var value=raw[index];
        if (!(value instanceof Dictionary)) { return null; }
        var entry=value as Dictionary; var id=entry["id"]; var name=entry["fit_name"];
        if (!(id instanceof String) || id.length()!=36 || !(name instanceof String) || name.length()==0 ||
            !(entry["name"] instanceof String) || !(entry["date"] instanceof String) || seen.hasKey(id) || names.hasKey(name)) { return null; }
        seen[id]=true; names[name]=true; result.add(entry);
    }
    return result;
}

// Una copia local no acredita permiso ni vigencia: exigir la lista actual completa.
function ciqManifestAllowsOpen(data as Dictionary,id as String,name as String) as Boolean {
    var entries=ciqManifestEntries(data);
    if (entries==null) { return false; }
    for (var index=0;index<entries.size();index++) {
        var entry=entries[index];
        if ((entry["id"] as String).equals(id) && (entry["fit_name"] as String).equals(name)) { return true; }
    }
    return false;
}
