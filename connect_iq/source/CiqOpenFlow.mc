import Toybox.Lang;
import Toybox.System;

// Un flujo por pantalla: una autorización vigente solo permite un intento nativo.
// Salir invalida respuestas tardías; reintentar exige una pantalla y consulta nuevas.
class CiqOpenFlow {
    private var _phase as Symbol=:idle;
    private var _id as String;
    private var _name as String;
    function initialize(id as String,name as String) { _id=id; _name=name; }
    function phase() as Symbol { return _phase; }
    function begin() as Boolean {
        if (_phase!=:idle) { return false; }
        _phase=:checking; return true;
    }
    function authorize(data as Dictionary) as Boolean {
        if (_phase!=:checking) { return false; }
        if (!ciqManifestAllowsOpen(data,_id,_name)) { _phase=:failed; return false; }
        _phase=:ready; return true;
    }
    function takeLaunch() as Boolean {
        if (_phase!=:ready) { return false; }
        _phase=:launching; return true;
    }
    function handedOff() as Void { if (_phase==:launching) { _phase=:handedOff; } }
    function fail() as Void { _phase=:failed; }
    function cancel() as Void { _phase=:cancelled; }
}

function ciqOpenErrorCode(error as Lang.Exception) as String {
    if (error instanceof System.PreviousOperationNotCompleteException) { return "pending"; }
    if (error instanceof System.AppNotInstalledException) { return "not_installed"; }
    if (error instanceof System.UnexpectedAppTypeException) { return "wrong_type"; }
    return "native_error";
}
