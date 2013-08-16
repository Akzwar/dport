module dport.gui.element;

import derelict.opengl3.gl3;

import dport.gl.object;

public import dport.gui.base;

import dport.utils.system;
mixin( defaultModuleLogUtils("ElemException") );

import dport.gui.langpack;

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
    gl_Position = vec4( 2.0 * vec2(vertex.x, -vertex.y) / winsize + vec2(-1.0,1.0), -0.05, 1 );
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
        gl_FragColor = vec4( 1, 1, 1, texture2D( ttu, ex_uv ).r ) * ex_color;
    else if( use_texture == 2 )
        gl_FragColor = texture2D( ttu, ex_uv );
}
"
};

/++ информация переносимая от родителя потомкам +/
class ElementInfo
{
    /++ шейдер +/
    ShaderProgram shader;

    LangPack lpack;

    /++ dpi for lenovo y580 +/
    uint dpi = 141;

    @property nothrow float mm2px_coef() const { return 0.0393700787f * dpi; }
    nothrow int mm2px( float val ) const { return cast(int)( mm2px_coef * val ); }

    this() 
    { 
        shader = new ShaderProgram( SS_ELEMENT );
        lpack = new LangPack;
    }
}

/++ интерфейс расскладки +/
interface Layout { void opCall( irect, Element[] ); }

/++
 родоначальник gui элементов
 +/
class Element: BaseViewRect
{
private:

    /++ информация может быть обновлена исключительно у элемента root +/
    enum setInfoOnlyParent = false;
    static if( setInfoOnlyParent ) { bool setInfoFlag = false; }

    /++ обновляет информацию для себя и всех дочерних элементов +/
    void setInfo( ElementInfo newInfo )
    {
        static if( setInfoOnlyParent )
        {
        if( !setInfoFlag && parent !is null ) 
            throw new ElemException( "new info must set in parent" );
        }
        info = newInfo;
        foreach( ch; childs )
        {
            static if( setInfoOnlyParent )
            {
            ch.setInfoFlag = true;
            }
            ch.updateInfo( newInfo );
        }
        static if( setInfoOnlyParent )
        {
        setInfoFlag = false;
        }
    }

    /++ смещение дочерних элементов относительно родительского элемента +/
    @property ivec2 innerOffset() const { return rect.pos + inner; }

    /++ смещение от верхнего левого края +/
    @property ivec2 offset() const
    {
        if( parent ) return innerOffset + parent.offset;
        else return innerOffset;
    }

    /++ полная высота окна +/
    @property int fullH() const 
    {
        if( parent ) return parent.fullH;
        else return rect.h;
    }

    /++ перевод координат мыши в локальные для передачи в дочерние +/
    ivec2 localMouse( in ivec2 mpos ){ return mpos - innerOffset; }

    /++ область отрисовки в координатах родительского +/
    irect drawRegion;

    /++ используется дочерними элементами для определения области отрисовки +/
    irect getVisible( in irect ch )
    {
        irect buf = ch;
        auto off = innerOffset;
        buf.pos += off;
        auto ret = drawRegion.overlap( buf );
        ret.pos -= off;
        return ret;
    }

    /++ выставляет viewport и scissor области +/
    void setView()
    { 
        drawRegion = rect;

        auto view = rect;
        auto draw = rect;

        if( parent )
        {
            drawRegion = parent.getVisible( rect );

            auto off = parent.offset;

            view.pos += off;

            draw = drawRegion;
            draw.pos += off;
        }

        glViewport( view.x, fullH - (view.y + view.h), view.w, view.h ); 
        glScissor( draw.x, fullH - (draw.y + draw.h), draw.w, draw.h );
    }

    /++ работа с шейдером и отключение проверки глубины +/
    void predraw()
    {
        glDisable( GL_DEPTH_TEST );
        info.shader.setUniformVec( "winsize", vec2( rect.size ) );
        info.shader.setUniform!int( "use_texture", 0 );
        info.shader.use();
    }

    /++ захват фокуса +/
    bool focus_grab = false;

    /++ родитель удаляет из списка всех умерших детей +/
    bool life = true;

protected:

    /++ самоликвидация +/
    final void selfDestruction() { life = false; }

    /++ обрабатывает ли элемент события +/
    bool processEvent = true;

    /++ общая для всех элементов информация +/
    ElementInfo info;

    /++ родительский элемент +/
    Element parent;

    /++ список дочерних элементов +/
    Element[] childs;

    /++ текущий дочерний элемент +/
    Element cur;

    /++ workaround 1: в debug версии сбор мёртвых происходит сюда +/
    debug static Element[] garbage;

    /++ внутреннее смещение области для дочерних элементов +/
    ivec2 inner = ivec2( 0,0 );

    final @property bool grab() const { return focus_grab; }
    final @property void grab( bool g )
    {
        focus_grab = g;
        if( parent ) parent.grab = g;
    }

    /++ поиск дочернего элемента для передачи события +/
    bool find( in ivec2 mpos )
    {
        /+ если фокус захвачен, поиск не производится +/
        if( focus_grab ) return cast(bool)cur;

        foreach( v; childs )
        {
            if( v !is null 
                    && v.life 
                    && v.processEvent 
                    && v.visible 
                    && ( mpos in v.activeArea ) )
            {
                if( cur != v ) 
                {
                    if( cur !is null )
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

    void add( Element e )
    {
        if( e == this ) throw new ElemException( "add this to this" );
        childs ~= e;
        e.updateInfo( info );
        e.parent = this;
        if( layout !is null ) layout( rect, childs );
    }

    //void remove( Element e )
    //{
    //    foreach( i, ch; childs )
    //    {
    //        if( ch == e )
    //        {
    //            childs = childs[0 .. i] ~ ( i < childs.length ? childs[i+1 .. $] : [] );
    //            break;
    //        }
    //    }
    //}

    bool is_visible = true;

public:

    @property nothrow bool visible() const { return is_visible; }
    @property void visible( bool vis ) { is_visible = vis; if( !vis ) release(); }

    //void reparent( Element newParent )
    //{
    //    if( newParent == this ) 
    //        throw new ElemException( "new parent from this is this" );
    //    if( parent ) parent.remove( this );
    //    newParent.add( this );
    //}

    @property irect drawRect() const { return drawRegion; }
    @property irect activeArea() const { return rect; }

    Signal!ElementInfo updateInfo;

    //alias void delegate( irect, Element[] ) Layout;
    Layout layout;

    this( Element par=null )
    {
        parent = par;

        updateInfo.connect( &setInfo );
        updateInfo.connect( (ei){ update(); } );

        if( par ) par.add( this );
        else info = new ElementInfo();

        draw.addBegin( &setView );
        draw.addBegin( &predraw );
        draw.addEnd( (){ 
                if( drawRegion.area <= 0 ) return;
                foreach_reverse( ch; childs ) 
                    if( ch !is null && ch.visible ) 
                        ch.draw(); 
                });

        keyboard.addCondition( (mpos, key){ return find( localMouse( mpos ) ); }, false );
        keyboard.connectAlt( (mpos, key){
                if( cur !is null ) cur.keyboard( localMouse( mpos ), key );
                });

        mouse.addCondition( (mpos, me){ return find( localMouse( mpos ) ); }, false );
        mouse.connectAlt( (mpos, me){
                if( cur !is null ) cur.mouse( localMouse( mpos ), me );
                });

        joystick.addCondition( (mpos, je){ return find( localMouse( mpos ) ); }, false );
        joystick.connectAlt( (mpos, je){
                if( cur !is null ) cur.joystick( localMouse( mpos ), je );
                });

        release.connect( (){ if( cur !is null ) cur.release(); } );
        release.connect( (){ if( parent !is null ) parent.grab = false; } );
        //if( parent )
        //    release.connect( (){ parent.grab = false; } );

        reshape.connect( (r){ if( layout !is null ) layout( r, childs ); } );

        update.connect( (){ foreach( ch; childs ) ch.update(); } );

        idle.connect( ( dtime ) {
            Element[] buf;
            foreach( ch; childs ) 
            {
                if( ch !is null && ch.life ) buf ~= ch;
                debug { 
                    if( ch is null || !ch.life ) 
                    {
                        garbage ~= ch;
                        ch.parent = null;
                    }
                }
            }
            if( buf.length != childs.length && layout !is null )
                layout( rect, buf );
            childs = buf[];

            foreach( ch; childs ) ch.idle( dtime );
                });
    }

    ~this()
    {
        foreach( ch; childs ) clear( ch );
        debug foreach( g; garbage ) clear( g );
    }
}
