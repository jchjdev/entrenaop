import Toybox.Graphics;
import Toybox.Lang;

// Medir antes de partir: los caracteres no tienen una anchura uniforme.
function ciqWrapText(text as String,width as Number,measure as Method(text as String) as Number) as Array<String> {
    var lines=[] as Array<String>; var start=0;
    while (start<text.length()) {
        var end=start; var space=-1;
        while (end<text.length()) {
            var character=text.substring(end,end+1) as String;
            if (character.equals("\n")) { break; }
            if (measure.invoke(text.substring(start,end+1) as String)>width) { break; }
            if (character.equals(" ")) { space=end; }
            end++;
        }
        if (end<text.length() && !(text.substring(end,end+1) as String).equals("\n") && space>start) {
            end=space;
        }
        if (end==start) { end++; }
        lines.add(text.substring(start,end) as String); start=end;
        while (start<text.length()) {
            var next=text.substring(start,start+1) as String;
            if (!next.equals(" ") && !next.equals("\n")) { break; }
            start++;
        }
    }
    return lines;
}

class CiqTextMeasure {
    private var _dc as Graphics.Dc;
    private var _font as Graphics.FontType;
    function initialize(dc as Graphics.Dc,font as Graphics.FontType) { _dc=dc; _font=font; }
    function width(text as String) as Number { return _dc.getTextWidthInPixels(text,_font); }
}

// El rectángulo central (78 % × 60 %) cabe dentro del círculo del reloj.
// Título, mensajes y botones comparten el ajuste; ninguna acción queda al borde.
function ciqDrawScreen(dc as Graphics.Dc,texts as Array<String>) as Void {
    dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
    var side=dc.getWidth()<dc.getHeight()?dc.getWidth():dc.getHeight();
    var width=(side*0.78).toNumber(); var height=(side*0.60).toNumber();
    var fonts=[Graphics.FONT_XTINY,Graphics.FONT_SYSTEM_XTINY] as Array<Graphics.FontType>;
    var lines=[] as Array<String>; var font=fonts[0]; var lineHeight=0;
    for (var index=0;index<fonts.size();index++) {
        font=fonts[index]; var measure=new CiqTextMeasure(dc,font); lines=[] as Array<String>;
        for (var part=0;part<texts.size();part++) {
            lines.addAll(ciqWrapText(texts[part],width,measure.method(:width)));
        }
        lineHeight=dc.getFontHeight(font)+2;
        if (lines.size()*lineHeight<=height) { break; }
    }
    var top=(dc.getHeight()-lines.size()*lineHeight)/2;
    for (var row=0;row<lines.size();row++) {
        dc.drawText(dc.getWidth()/2,top+row*lineHeight,font,lines[row],Graphics.TEXT_JUSTIFY_CENTER);
    }
}
