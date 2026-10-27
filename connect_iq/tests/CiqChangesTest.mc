import Toybox.Lang;
import Toybox.Test;

function ciqChangesTestRevision() as String {
    return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
}
(:test)
function changesRequireCompleteValidResponse(logger as Test.Logger) as Boolean {
    var revision=ciqChangesTestRevision();
    return ciqChangesRevision({"revision"=>revision,"count"=>1,"blocked"=>0})!=null &&
        ciqChangesRevision({"revision"=>revision,"count"=>0,"blocked"=>0})!=null &&
        ciqChangesRevision({"revision"=>revision,"count"=>1})==null &&
        ciqChangesRevision({"revision"=>revision,"count"=>31,"blocked"=>0})==null &&
        ciqChangesRevision({"revision"=>revision,"count"=>1,"blocked"=>-1})==null &&
        ciqChangesRevision({"revision"=>"no es una huella","count"=>1,"blocked"=>0})==null &&
        ciqChangesRevision({"revision"=>"z"+revision.substring(1,64),"count"=>1,"blocked"=>0})==null;
}
(:test)
function alertsRequireOptInAndOnlyNewRevision(logger as Test.Logger) as Boolean {
    var revision=ciqChangesTestRevision();
    return !ciqShouldAlert(false,revision,null,null) &&
        ciqShouldAlert(true,revision,null,null) &&
        !ciqShouldAlert(true,revision,revision,null) &&
        !ciqShouldAlert(true,revision,"otra",revision) &&
        ciqShouldAlert(true,revision,"anterior","avisada antes");
}
