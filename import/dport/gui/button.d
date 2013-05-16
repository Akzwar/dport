module dport.gui.button;

import derelict.opengl.gl;

import dport.gl.shader,
       dport.gl.object;

import dport.gui.base,
       dport.gui.element,
       dport.gui.drawtext;

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

    void mouse_hook( in ivec2, in MouseEvent me )
    { 
        if( me.type == me.Type.RELEASED ) 
        {
            if( prepare ) onClick(); 
            prepare = 0;
        }
        if( me.type == me.Type.PRESSED ) 
        {
            prepare = 1;
            onPress();
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
            elem.setRect( bbox );
        }
    }

public:
    EmptySignal onClick;
    EmptySignal onPress;

    this( Element par, in irect rect )
    {
        super( par );

        bbox = rect;
        mouse.connect( &mouse_hook );
        reshape.connect( (r){ foreach( elem; content ) elem.setRect( r ); });
        draw.connect( (){ foreach( elem; content ) elem.onDraw(); });
        idle.connect( (dtime){ foreach( elem; content ) elem.onIdle(dtime); }); 
        release.connect( (){ prepare = 0; } );
    }
}

class ButtonLabel: ButtonDrawContent
{
    TextString label;
    this( Element parent, wstring text, uint h=14 )
    {
        label = new TextString( parent );
        label.setTextParam( TextParam( text, h ), 1 );
    }

    void setText( wstring text )
    {
        label.setTextParam( TextParam( text ), 1 );
    }

    override // ButtonDrawContent
    {
        void setRect( in irect r ) { label.reshape( irect( 0, 0, r.w, r.h ) ); }

        void onDraw() { /+label.draw();+/ }
        void onIdle( real dtime ){ }

        void onActive() { }
        void onRelease() { }

        void onPress() { }
        void onClick() { }
    }
}

class ButtonShape: GLVAO, ButtonDrawContent
{
    static float[] posdata( in irect r )
    { return [ 0.0f, 0, 0, r.h, r.w, r.h, r.w, 0 ]; }
    //{ return [ r.x*1.0f, r.y, r.x, r.y+r.h, r.x+r.w, r.y+r.h, r.x+r.w, r.y ]; }

    static float[] coldata( in col4 c )
    { return c.data ~ c.data ~ c.data ~ c.data; }

    auto not_active_col = col4( .3f, .3f, .3f, .8f );
    auto is_active_col  = col4( .1f, .6f, .9f, .6f );
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

        draw.connect( (){ glDrawArrays( GL_QUADS, 0, 4 ); } );
    }

    override // ButtonDrawContent
    {
        void setRect( in irect r ) { bufferData( "pos", posdata( r ) ); }

        void onDraw() { draw(); }

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
    ButtonLabel label;
    ButtonShape shape;

    this( Element par, in irect rect, wstring str=""w, void delegate() onclick=null )
    {
        super( par, rect );

        shape = new ButtonShape( this.shader, rect );
        label = new ButtonLabel( this, str, rect.h - 10 );

        content ~= shape;
        content ~= label;

        setUpContent();

        if( onclick !is null )
            onClick.connect( onclick );
    }

    void setLabel( wstring str )
    {
        label.setText( str );
    }
}
