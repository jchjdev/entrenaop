import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

class CiqTestTextMeasure {
    function initialize() { }
    function width(text as String) as Number {
        var width=0;
        for (var index=0;index<text.length();index++) {
            width+=(text.substring(index,index+1) as String).equals("W")?4:1;
        }
        return width;
    }
}
(:test)
function screenWrapMeasuresGlyphsAndPreservesWords(logger as Test.Logger) as Boolean {
    var measure=new CiqTestTextMeasure();
    var lines=ciqWrapText("WW hola Garmin",8,measure.method(:width));
    return lines.size()==3 && lines[0].equals("WW") && lines[1].equals("hola") && lines[2].equals("Garmin");
}
(:test)
function screenWrapKeepsEveryButtonAndBreaksLongTokens(logger as Test.Logger) as Boolean {
    var measure=new CiqTestTextMeasure();
    var lines=ciqWrapText("START: volver\nMENU: detalle",20,measure.method(:width));
    var token=ciqWrapText("123456789012",5,measure.method(:width));
    return lines.size()==2 && lines[0].equals("START: volver") && lines[1].equals("MENU: detalle") &&
        token.size()==3 && token[0].equals("12345") && token[1].equals("67890") && token[2].equals("12") &&
        ciqWrapText("",20,measure.method(:width)).size()==0;
}
(:test)
function retryIsLimitedToTransportFailures(logger as Test.Logger) as Boolean {
    return ciqConnectionCanRetry(-300) && ciqConnectionMessage(-300).equals("Tiempo de espera agotado") &&
        ciqConnectionCanRetry(Communications.BLE_CONNECTION_UNAVAILABLE) &&
        !ciqConnectionCanRetry(401) && !ciqConnectionCanRetry(403) && !ciqConnectionCanRetry(500) &&
        !ciqConnectionCanRetry(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
}
