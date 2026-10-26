import Toybox.Lang;
import Toybox.Test;

function ciqTestEntry() as Dictionary {
    return {"id"=>"10000000-0000-4000-8000-000000000001","name"=>"Fuerza propia",
        "fit_name"=>"Fuerza propia · 1000000000","date"=>"2026-10-26"};
}
(:test)
function withdrawnOrChangedWorkoutCannotOpenCachedCopy(logger as Test.Logger) as Boolean {
    var entry=ciqTestEntry();
    return !ciqManifestAllowsOpen({"complete"=>true,"entries"=>[]},entry["id"] as String,entry["fit_name"] as String) &&
        !ciqManifestAllowsOpen({"complete"=>true,"entries"=>[entry]},entry["id"] as String,"Otra revisión");
}
(:test)
function onlyCurrentCompleteManifestAllowsOpen(logger as Test.Logger) as Boolean {
    var entry=ciqTestEntry();
    return !ciqManifestAllowsOpen({"complete"=>false,"entries"=>[entry]},entry["id"] as String,entry["fit_name"] as String) &&
        ciqManifestAllowsOpen({"complete"=>true,"entries"=>[entry]},entry["id"] as String,entry["fit_name"] as String);
}
(:test)
function incompleteManifestCannotReplaceCurrentList(logger as Test.Logger) as Boolean {
    return ciqManifestEntries({"complete"=>false,"entries"=>[ciqTestEntry()]})==null;
}
(:test)
function duplicateNativeIdentitiesAreRejected(logger as Test.Logger) as Boolean {
    return ciqManifestEntries({"complete"=>true,"entries"=>[ciqTestEntry(),ciqTestEntry()]})==null;
}
(:test)
function validEmptyManifestWithdrawsAllFromAppMenu(logger as Test.Logger) as Boolean {
    var result=ciqManifestEntries({"complete"=>true,"entries"=>[]});
    return result!=null && result.size()==0;
}
(:test)
function validManifestKeepsOwnNamesAndIds(logger as Test.Logger) as Boolean {
    var result=ciqManifestEntries({"complete"=>true,"entries"=>[ciqTestEntry()]});
    return result!=null && result.size()==1 && (result[0]["name"] as String).equals("Fuerza propia");
}
