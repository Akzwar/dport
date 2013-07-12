/++
Отрисовка текста в gui
 +/
module dport.gui.drawtext;

import derelict.opengl3.gl3;

import dport.math.types;
import dport.utils.system;

import dport.gl.shader;
import dport.gl.object;
import dport.gl.texture;

import dport.gui.element;

import std.string;

mixin( defaultModuleLogUtils("DTException") );

alias vrect!int irect; /// прямоугольник целочисленный
alias vrect!float frect; /// прямоугольник плавающеточечный
alias GLTexture!2 GLTexture2D; /// текстура двумерная

/++
содержит информацию о отрендеренном символе
 +/
struct GlyphInfo
{
    irect rect; /// размер изображения символа
    ivec2 next; /// смещение для следующего изображения
    ubyte[] buffer; /// пиксельная информация
}

/++
интерфейс рендера шрифтов
 +/
interface FontRender
{
    /++
        установить размер шрифта
        Params:
        sz = размер шривта 
     +/
    void setSize( uint sz );
    /++
        отрендерить символ
        Params: ch = номер символа в таблице unicode
        Returns: структура с информацией о отрендеренном символе
     +/
    GlyphInfo renderChar( size_t ch );
}

version(Windows)
{

static assert( 0, "no realisation of FontRender for windows" );

class WindowsTypeRender: FontRender
{
public:
    this( string fontname )
    {

    }

    override void setSize( uint sz )
    {

    }

    override GlyphInfo renderChar( size_t ch )
    {

    }
}

} else {

import derelict.freetype.ft;
import derelict.freetype.types;

static this() { DerelictFT.load(); }

/++
    FreeType реализация интерфеса рендеринга символов 
 +/
class FreeTypeRender: FontRender
{
private:
    FT_Library ft;
    FT_Face face;

    /++
        конструктор так то
        Params:
        fontname = полное имя загружаемого шрифта (вместе с путём)
     +/
    this( string fontname )
    {
        if( FT_Init_FreeType( &ft ) )
            throw new DTException( "Couldn't init freetype library" );
        debug log.info( "lib loaded" );

        if( FT_New_Face( ft, fontname.ptr, 0, &face ) )
            throw new DTException( "Couldn't open font \"" ~ fontname ~ "\"" );
        debug log.info( "font \"", fontname, "\" loaded" );

        if( FT_Select_Charmap( face, FT_Encoding.FT_ENCODING_UNICODE ) )
            throw new DTException( "Couldn't select unicode enc" );
        debug log.info( "unicode encoding selected" );
    }

    static FreeTypeRender[string] openFTR;
public:

    /++ 
        фиксится баг связанный с невозможностью открытия множества экземпляров одного шрифта
        дополнительная оптимизация
    +/
    static FontRender get( string fontname )
    {
        if( fontname !in openFTR ) 
        {
            openFTR[fontname] = new FreeTypeRender( fontname );
            debug log.info( "new FreeType font opened: " ~ fontname );
        }
        return openFTR[fontname];
    }

    override void setSize( uint sz ) { FT_Set_Pixel_Sizes(face, 0, sz); }

    override GlyphInfo renderChar( size_t ch )
    {
        if( FT_Load_Char(face, ch, FT_LOAD_RENDER) ) 
            throw new DTException( "Couldn't load character" );
        debug log.trace( "load char: \"", cast(wchar)ch, "\"" );
        auto g = face.glyph;
        
        debug log.trace( "bitmap size: ", g.bitmap.width, "x", g.bitmap.rows );
        auto ret = GlyphInfo( irect( g.bitmap_left, g.bitmap_top, 
                g.bitmap.width, g.bitmap.rows ),
                ivec2( cast(int)(g.advance.x >> 6), cast(int)(g.advance.y >> 6) ) );
        ret.buffer.length = ret.rect.w * ret.rect.h;
        foreach( i, ref buf; ret.buffer  )
                buf = g.bitmap.buffer[i];
        return ret;
    }

    ~this()
    {
        debug log.Debug( "FreeTypeRender destructor start" );
        FT_Done_Face( face );
        debug log.info( "font done" );
        FT_Done_FreeType( ft );
        debug log.info( "lib done" );
        debug log.Debug( "FreeTypeRender destructor end" );
    }
}

}

/++
 информация об отрисовываемом текте
 +/
struct TextParam
{
    wstring str=""; /// как таковой текст
    uint height=12; /// высота шрифта
    col4 color=col4(1,1,1,1); /// цвет
    vec2 pos=vec2(0,0); /// позиция, согласно шейдеру, в оконных координатах
}

/++
 отрисовка строки текста
 +/
class TextString: Element
{
private:
    /++ 
        выставляет в шейдере uniform текстуру и флаг использования 1
     +/
    void predraw()
    {
        shader.setUniform!int( "use_texture", 1 );
        shader.setUniform!int( "ttu", GL_TEXTURE0 );
        tex.use();
    }

    class _drawrect: GLVAO
    {
        static float[] vecToArray(string S,T)( vec!(S,T)[] arr, ulong count=4 ) 
        {
            float[] ret;
            foreach( i; 0 .. count ) ret ~= arr[i%arr.length].data;
            return ret;
        }

        this( ShaderProgram sp )
        {
            super( sp );
            genBufferWithData( "crd", [ 0,  0, 100, 0, 0, 10, 100, 10 ] );
            setAttribPointer( "crd", "vertex", 2, GL_FLOAT );

            genBufferWithData( "clr", vecToArray( [col4( 1.0, 1.0, 1.0, 1.0 )] ) );
            setAttribPointer( "clr", "color", 4, GL_FLOAT );

            //genBufferWithData( "uv", [ 0.0f,  0, 1,  0,  0,  1, 1, 1 ] );
            genBufferWithData( "uv", [ 0.0f,  1, 1,  1,  0,  0, 1, 0 ] );
            setAttribPointer( "uv", "uv", 2, GL_FLOAT );

            this.draw.connect( (mtr){ glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 ); } );
        }

        void setColor( in col4 c ) { bufferData( "clr", vecToArray( [c] ) ); }
        void reshape( in irect r ) 
        { 
            irect rr = r;
            if( center ) 
            {
                rr.x = ( bbox.w - r.x - r.w ) / 2;
                rr.y = cast(int)(bbox.h/2.0 + r.y - tp.height/3.0);
            }
            bufferData( "crd", rr.points!float( vec2(0,0) ) );
        }
    }

    _drawrect dr;

protected:

    GLTexture2D tex;
    FontRender fr;
    TextParam tp;
    bool center = 0;

    /++ рендерит текст, обновляет текстуру и boundingbox (bbox) +/
    void update()
    { 
        /+ fix redraw buf +/
        GlyphInfo resbuf;
        resbuf.rect = irect(0,0,1,1);
        res.buffer.length = 1;
        fillTexture( resbuf );

        /+ fix empty str exception +/
        if( tp.str == "" ) return;

        uint th = tp.height;
        fr.setSize( th );
        auto pen = ivec2( 0, 0 );

        GlyphInfo[] buf;

        auto min = ivec2( 32000, 32000 );
        auto max = ivec2( -32000, -32000 );

        void findminmax( in ivec2 v )
        {
            if( min.x > v.x ) min.x = v.x;
            if( min.y > v.y ) min.y = v.y;
            if( max.x < v.x ) max.x = v.x;
            if( max.y < v.y ) max.y = v.y;
        }


        foreach( i, ch; tp.str )
        {
            auto g = fr.renderChar( ch );
            g.rect.pt[0] += pen;
            pen += g.next;
            buf ~= g;

            findminmax( g.rect.pt[0] );
            findminmax( g.rect.pt[0] + ivec2( g.rect.w, -g.rect.h ) );
        }

        res.rect = irect( min, max - min );
        res.buffer.length = res.rect.w * res.rect.h;

        foreach( g; buf )
        {
            auto yy = res.rect.h - ( g.rect.y - min.y );
            auto xx = g.rect.x - min.x;
            foreach( r; 0 .. g.rect.h )
                foreach( v; 0 .. g.rect.w )
                {
                    size_t index = (yy + r) * res.rect.w + xx + v;
                    res.buffer[ index ] = g.buffer[ r * g.rect.w + v ];
                }
        }
        fillTexture( res );
        dr.setColor( tp.color );
    }
    GlyphInfo res;

    void fillTexture( GlyphInfo g )
    {
        tex.image( GL_ALPHA, isize( g.rect.w, g.rect.h ), GL_ALPHA,
                GL_UNSIGNED_BYTE, g.buffer.ptr );
    }

public:

    /++
        конструктор 

        Params:
        sp = шейдер, предположительно единый для всего gui-текста
        fontname = имя шрифта
     +/
    this( Element par, string fontname )
    {
        super( par );
        this.processEvent = 0;

        dr = new _drawrect( this.shader );
        tex = new GLTexture2D( isize( 100, 10 ) );

        version(Windows) 
        { 
            debug log.info( "use WINDOWS_WTF" );
            fr = new WindowsTypeRender( fontname );
        }
        else
        {
            debug log.info( "use FreeType" );
            fr = FreeTypeRender.get( fontname.idup );
        }

        draw.addPair( &predraw, (){ tex.use(0); } );
        draw.addOpen( (){ dr.reshape( res.rect ); } );
        draw.connect( (){ dr.draw.opCall( mat4() ); } );

        debug log.info( "TextString create" );
    }

    /++ выставляет новые параметры текста +/
    final void setTextParam( in TextParam ntp, bool align_center=0 )
    { 
        tp = ntp; 
        center = align_center;
        update();
    }
}

/++
 отрисовка текста
 TODO: дополнить различными рюшечками
 +/
class Text: Element
{
private:
    TextString[] strs;

    TextParam tp;
    bool center;
    string fontname;

    void update()
    {
        auto sp = splitLines( tp.str );
        while( sp.length > strs.length )
            strs ~= new TextString( this, fontname );
        
        //while( sp.length < strs.length )
        //{
        //    clear( strs[$-1] );
        //    strs = strs[0 .. $-1];
        //}

        int k = 0;
        foreach( i, s; sp )
        {
            auto ptp = tp;
            ptp.str = s;
            strs[i].setTextParam( ptp, center );
            k = cast(int)(i * tp.height * 1.5);
            strs[i].reshape( irect( 0, k, strs[i].res.rect.w, strs[i].res.rect.h ) );
        }
    }

public:

    /++
        конструктор 

        Params:
        sp = шейдер, предположительно единый для всего gui-текста
        fontname = имя шрифта
     +/
    this( Element par, string fname )
    {
        super( par );
        this.processEvent = 0;

        version(Windows) 
        { 
            debug log.info( "use WINDOWS_WTF" );
        }
        else
        {
            debug log.info( "use FreeType" );
            FreeTypeRender.get( fname.idup );
        }

        fontname = fname;
    }

    /++ выставляет новые параметры текста +/
    final void setTextParam( in TextParam ntp, bool align_center=0 )
    { 

        tp = ntp; 
        center = align_center;
        update();
    }
}
