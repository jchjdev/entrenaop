import Toybox.Lang;

// Solo una respuesta completa del contrato de cambios puede provocar un aviso.
(:background)
function ciqChangesRevision(data as Dictionary) as String? {
    var revision=data["revision"]; var count=data["count"]; var blocked=data["blocked"];
    if (!(revision instanceof String) || revision.length()!=64 ||
        !(count instanceof Number) || count<0 || count>30 ||
        !(blocked instanceof Number) || blocked<0 || blocked>30) { return null; }
    for (var index=0;index<revision.length();index++) {
        if ("0123456789abcdef".find(revision.substring(index,index+1) as String)==null) { return null; }
    }
    return revision;
}

// No repetir el diálogo rechazado ni avisar por una revisión ya instalada.
(:background)
function ciqShouldAlert(enabled as Boolean,revision as String,local as String?,notified as String?) as Boolean {
    return enabled && (local==null || !revision.equals(local)) &&
        (notified==null || !revision.equals(notified));
}
