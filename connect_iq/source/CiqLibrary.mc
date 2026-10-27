import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Time;

// La descarga de fondo puede aparecer en Fuerza sin figurar en getAppWorkouts.
// Solo recuperar un alias exacto previamente solicitado; nunca atribuir propiedad
// ni eliminar contenido encontrado en la biblioteca general.
class CiqLibrary {
    function initialize() { }
    function findApp(name as String) as PersistedContent.Content? {
        return unique(PersistedContent.getAppWorkouts(),name);
    }
    function findNative(name as String) as PersistedContent.Content? {
        return unique(PersistedContent.getWorkouts(),name);
    }
    private function unique(iterator as PersistedContent.Iterator,name as String) as PersistedContent.Content? {
        var found=null as PersistedContent.Content?; var content=iterator.next();
        while (content!=null) {
            if (content.getName().equals(name)) {
                if (found!=null) { return null; }
                found=content;
            }
            content=iterator.next();
        }
        return found;
    }
    function find(name as String) as PersistedContent.Content? {
        var content=findApp(name); var scope="propia";
        if (content==null && ciqSyncTrustsNative(name)) { content=findNative(name); scope="general"; }
        if (content!=null && ciqSyncTrustsNative(name)) {
            var records=ciqSyncRecords(); var record=records[name];
            if (!(record instanceof Dictionary)) { record={"attempts"=>1,"origin"=>"ensayo 1.5"}; }
            record["phase"]="verified"; record["native_id"]=content.getId(); record["library"]=scope;
            record["verified_at"]=Time.now().value(); records[name]=record;
            Storage.setValue("ciqSyncRecords",records as Storage.ValueType);
        }
        return content;
    }
}
