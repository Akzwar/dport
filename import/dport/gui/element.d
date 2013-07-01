module dport.gui.element;

import derelict.opengl3.gl3;

import dport.gl.shader,
       dport.gl.object;

public import dport.gui.base;

import dport.utils.system;
mixin( defaultModuleLogUtils("ElemException") );

import std.conv;

/++
 стандартный шейдер для всех gui элементов

    uniform vec2 winsize - размер окна

    attribute vec2 vertex - позиция в системе координат окна
    attribute vec4 color - цвет вершины
    attribute vec2 uv - текстурная координата

    uniform sampler2D ttu - текстурный сэмплер
    uniform int use_texture - флаг использования текстуры: 
                                0 - не использовать,
                                1 - использовать только альфу
                                2 - использовать все 4 канала текстуры

 +/
enum ShaderSources SS_ELEMENT = 
{
r"
#version 130
uniform vec2 winsize;

in vec2 vertex;
in vec4 color;
in vec2 uv;

out vec2 ex_uv;
out vec4 ex_color;

void main(void)
{
    gl_Position = vec4( 2.0 * vertex / winsize - vec2(1.0,1.0), -0.05, 1 );
    ex_uv = uv;
    ex_color = color;
}
", 

r"
#version 130
uniform sampler2D ttu;
uniform int use_texture;

in vec2 ex_uv;
in vec4 ex_color;

void main(void) 
{ 
    if( use_texture == 0 )
        gl_FragColor = ex_color; 
    else if( use_texture == 1 )
        gl_FragColor = vec4( 1, 1, 1, texture2D( ttu, ex_uv ).a ) * ex_color;
    else if( use_texture == 2 )
        gl_FragColor = texture2D( ttu, ex_uv );
}
"
};

/++
 родоначальник gui элементов
 +/
class Element: View
{
private:
    /++ возвращает смещение от верхнего левого края +/
    @property ivec2 offset() const
    {
        if( parent )
        {
            int x = bbox.x + parent.offset.x;
            int y = parent.offset.y + parent.bbox.h - ( bbox.y + bbox.h );
            return ivec2( x, y );
        }
        else return bbox.pt[0];
    }

    ivec2 localMouse( in ivec2 mpos ){ return mpos - bbox.pos; }

    void setViewport( in irect view )
    { glViewport( view.x, view.y, view.w, view.h ); }

    irect checkRect( in irect ch )
    {
        // TODO: продумать: область рисования ограничивается родителем
        return ch;
    }

    void predraw()
    {
        auto r = irect( offset, bbox.size );
        if( parent ) setViewport( parent.checkRect( r ) );
        else setViewport( r );
        glDisable( GL_DEPTH_TEST );
        shader.setUniformVec( "winsize", vec2( bbox.size ) );
        shader.setUniform!int( "use_texture", 0 );
        shader.use();
    }
protected:

    Element[] childs;
    Element cur;

    bool processEvent = true;

    bool find( in ivec2 mpos )
    {
        foreach_reverse( v; childs )
        {
            if( v !is null && v.processEvent && v.visible && ( mpos in v.rect ) )
            {
                if( cur != v ) 
                {
                    if( cur )
                        cur.release();
                    cur = v;
                    cur.activate();
                }
                return true;
            }
        }
        if( cur ) cur.release();

        cur = null;
        return false;
    }

    ShaderProgram shader;
    Element parent;

public:
    bool visible = true;

    this( Element par=null )
    {
        parent = par;
        if( par ) 
        {
            shader = par.shader;
            par.childs ~= this;
        }
        else 
            shader = new ShaderProgram( SS_ELEMENT );

        draw.addPair( &predraw, (){ 
                foreach_reverse( ch; childs ) 
                    if( ch.visible ) 
                        ch.draw(); 
                });

        keyboard.addCondition( (mpos, key){ 
                return find( localMouse( mpos ) ); 
                }, 0 );
        keyboard.connectAlt( ( mpos, key ){
                if( cur ) cur.keyboard( localMouse( mpos ), key );
                });

        mouse.addCondition( (mpos, me){ 
                return find( localMouse( mpos ) ); 
                }, 0 );
        mouse.connectAlt( ( mpos, me ){
                if( cur ) cur.mouse( localMouse( mpos ), me );
                });

        joystick.addCondition( (mpos, je){
                return find( localMouse( mpos ) );
                }, 0 );
        joystick.connectAlt( (mpos, je){
                if( cur ) cur.joystick( localMouse( mpos ), je );
                });

        release.connect( (){ if( cur ) cur.release(); } );

        idle.connect( ( dtime ) {
            foreach( ch; childs ) ch.idle( dtime );
                });
    }

    ~this()
    {
        //if( parent )
        //{
        //    foreach( i, ch; parent.childs )
        //        if( ch == this )
        //        {
        //            debug log.error( "OKDA" );
        //            parent.childs = parent.childs[0 .. i] ~ ( i < parent.childs.length ?
        //                                                parent.childs[i+1 .. $]:[] );
        //        }
        //}
    }
}
