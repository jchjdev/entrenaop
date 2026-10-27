import Toybox.Communications;
import Toybox.Lang;

// Solo fallos transitorios de transporte; nunca respuestas de permisos ni JSON inválido.
function ciqConnectionCanRetry(code as Number) as Boolean {
    return code==Communications.NETWORK_REQUEST_TIMED_OUT ||
        code==Communications.BLE_HOST_TIMEOUT || code==Communications.BLE_SERVER_TIMEOUT ||
        code==Communications.BLE_ERROR || code==Communications.BLE_CONNECTION_UNAVAILABLE ||
        code==Communications.BLE_QUEUE_FULL || code==Communications.REQUEST_CONNECTION_DROPPED;
}
function ciqConnectionMessage(code as Number) as String {
    if (code==Communications.NETWORK_REQUEST_TIMED_OUT || code==Communications.BLE_HOST_TIMEOUT ||
        code==Communications.BLE_SERVER_TIMEOUT) { return "Tiempo de espera agotado"; }
    return "Sin conexión con el móvil";
}
