module dport.gui.button;

import derelict.opengl3.gl3;

import dport.gl.shader,
       dport.gl.object;

import dport.gui.base,
       dport.gui.element,
       dport.gui.drawtext;

import dport.utils.system;
mixin( defaultModuleLogUtils( "ButtonException" ) );

interface ButtonDrawContent
{
    void setRect( in irect r );
    void onDraw();
    void onIdle( real dtime );

    void onActive();
    void onRelease();
    void onClick();
    void onPress();
}

abstract class Button: Element
{
protected:
    /++ full in child classes +/
    ButtonDrawContent[] content;

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
            onPress();
            grab = 1;
        }
    }

    // call before add all elems to content list
    void setUpContent()
    {
        foreach( i, elem; content )
        {
            activate.connect( &(elem.onActive) );
            release.connect( &(elem.onRelease) );
            onClick.connect( &(elem.onClick) );
            onPress.connect( &(elem.onPress) );
            elem.setRect( rect );
        }
    }

public:
    EmptySignal onClick;
    EmptySignal onPress;

    this( Element par, in irect r )
    {
        super( par );

        rect = r;
        mouse.connect( &mouse_hook );
        reshape.connect( (r){ foreach( elem; content ) elem.setRect( r ); });
        draw.connect( (){ foreach( elem; content ) elem.onDraw(); } );
        idle.connect( (dtime){ foreach( elem; content ) elem.onIdle(dtime); }); 
        release.connect( (){ prepare = 0; } );
    }

    ~this() { foreach( c; content ) clear( c ); }
}

//class ButtonLabel: ButtonDrawContent
//{
//    TextString label;
//    this( Element parent, string font, wstring text, uint h=14 )
//    {
//        label = new TextString( parent, font );
//        label.setTextParam( TextParam( text, h ), 1 );
//    }
//
//    void setText( wstring text )
//    {
//        label.setTextParam( TextParam( text ), 1 );
//    }
//
//    override // ButtonDrawContent
//    {
//        void setRect( in irect r ) { label.reshape( irect( 0, 0, r.w, r.h ) ); }
//
//        void onDraw() { /+label.draw();+/ }
//        void onIdle( real dtime ){ }
//
//        void onActive() { }
//        void onRelease() { }
//
//        void onPress() { }
//        void onClick() { }
//    }
//}

class ButtonShape: GLVAO, ButtonDrawContent
{
    static float[] posdata( in irect r )
    { return [ 0.0f, 0, 0, r.h, r.w, 0, r.w, r.h ]; }

    static float[] coldata( in col4 c )
    { return c.data ~ c.data ~ c.data ~ c.data; }

    auto not_active_col = col4( .3f, .3f, .3f, .6f );
    auto is_active_col  = col4( .1f, .6f, .9f, .8f );
    auto on_press_col   = col4( .8f, .7f, .1f, .9f );

    col4 curColor, lastColor;
    real speed = 10;

    this( ShaderProgram sh, in irect rect )
    {
        super( sh );

        genBufferWithData( "pos", posdata( rect ) );
        setAttribPointer( "pos", "vertex", 2, GL_FLOAT );

        genBufferWithData( "col", coldata( not_active_col ) );
        curColor = not_active_col;
        lastColor = not_active_col;
        setAttribPointer( "col", "color", 4, GL_FLOAT );

        draw.connect( (mtr){ glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 ); } );
    }

    override // ButtonDrawContent
    {
        void setRect( in irect r ) { bufferData( "pos", posdata( r ) ); }

        void onDraw() { draw( mat4() ); }

        void onIdle( real dtime ) 
        { 
            while( dtime * speed > 1.0 ) speed -= 5;
            lastColor += ( curColor - lastColor ) * speed * dtime;
            bufferData( "col", coldata( lastColor ) );
        }

        void onActive() { curColor = is_active_col; speed = 15; }
        void onRelease() { curColor = not_active_col; speed = 5; }

        void onPress() { curColor = on_press_col; speed = 250; }
        void onClick() { curColor = is_active_col; speed = 5; }
    }
}

class SimpleButton: Button
{
    ButtonShape shape;
    //ButtonLabel label;

    this( Element par, string font, in irect rect, wstring str=""w, void delegate() onclick=null )
    {
        super( par, rect );

        shape = new ButtonShape( this.info.shader, rect );
        //label = new ButtonLabel( this, font, str, rect.h - 10 );

        content ~= shape;
        //content ~= label;

        setUpContent();

        if( onclick !is null )
            onClick.connect( onclick );
    }

    void setLabel( wstring str )
    {
        //label.setText( str );
    }
}
