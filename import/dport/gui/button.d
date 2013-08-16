module dport.gui.button;

import derelict.opengl3.gl3;

import dport.gl.shader,
       dport.gl.object;

import dport.gui.base,
       dport.gui.element,
       dport.gui.drawtext,
       dport.gui.rshape;

import dport.utils.system;
mixin( defaultModuleLogUtils( "ButtonException" ) );

    import std.stdio;
abstract class Button: Element
{
private:
    bool prepare = 0;
    void mouse_hook( in ivec2 p, in MouseEvent me )
    { 
        if( me.type == me.Type.RELEASED ) 
        {
            if( prepare && p in drawRect )
                onClick(); 
            prepare = 0;
            grab = 0;
        }
        if( me.type == me.Type.PRESSED ) 
        {
            prepare = 1;
            grab = 1;
            onPress();
        }
    }
public:
    EmptySignal onClick;
    EmptySignal onPress;

    this( Element par, in irect r )
    {
        super( par );

        mouse.connect( &mouse_hook );
        release.connect( (){ prepare = 0; } );
        reshape( r );
    }
}

class SimpleButton: Button
{
    col4[string] color_sheme;
    col4 curColor, nColor;
    float speed = 10;

    RShape shape;
    TextElement label;

    this( Element par, string font, in irect r, wstring str=""w, void delegate() onclick=null )
    {
        super( par, r );

        shape = new RShape( this.info.shader );
        shape.notUseTexture();
        draw.connect( (){ shape.draw( mat4() ); } );

        label = new TextElement( this, font, false );
        label.textAlign = TextElement.TextAlign.CENTER;
        label.setTextData( TextData( str, r.h / 3 * 2 ) );
        label.baseLine = cast(int)(r.h * 0.7);

        reshape.connect( (r){ 
                auto inrect = irect( 0, 0, r.w, r.h );
                shape.reshape( inrect ); 
                label.reshape( inrect );
                } );

        if( onclick !is null )
            onClick.connect( onclick );

        color_sheme = [
            "default": col4( .3f, .3f, .3f, .6f ),
            "active":  col4( .1f, .6f, .9f, .8f ),
            "press":   col4( .8f, .7f, .1f, .9f ),
        ];

        curColor = color_sheme["default"];
        nColor = color_sheme["default"];

        idle.connect( (dt){
            if( dt * speed > 1.0 ) speed = 1.0 / dt;
            curColor += ( nColor - curColor ) * speed * dt;
            shape.setColor( curColor );
                } );

        activate.connect( (){ nColor = color_sheme["active"]; speed = 15; } );
        release.connect( (){ nColor = color_sheme["default"]; speed = 5; } );

        onPress.connect( (){ nColor = color_sheme["press"]; speed = 250; } );
        onClick.connect( (){ nColor = color_sheme["active"]; speed = 5;} );

        reshape( rect );
    }

    void setLabel( wstring str )
    { 
        label.setTextData( TextData( str, rect.h / 3 * 2 ) ); 
    }
}
