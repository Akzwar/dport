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
import dport.gui.rshape;

import std.string;

version(Windows)
{

}
else
{
    pragma(lib, "dl");

    version(DigitalMars)
    {
        pragma(lib, "Derelict3/lib/dmd/libDerelictGL3.a");
        pragma(lib, "Derelict3/lib/dmd/libDerelictFT.a");
        pragma(lib, "Derelict3/lib/dmd/libDerelictUtil.a");
    }
}

mixin( defaultModuleLogUtils("DTException") );

alias vrect!float frect; /// прямоугольник плавающеточечный

/++
содержит информацию о отрендеренном символе
 +/
struct GlyphInfo
{
    /++ размер изображения символа +/
    irect rect; 
    /++ смещение для следующего изображения +/
    ivec2 next; 
    /++ пиксельная информация +/
    ubyte[] buffer; 

    this(this) { buffer = buffer.dup; }
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
    /++ baseline-to-baseline height +/
    @property uint baseLineHeight();
}

version(Windows)
{

static assert( 0, "no realisation of FontRender for windows" );

class WindowsTypeRender: FontRender
{
public:
    this( string fontname ) { } 
    override void setSize( uint sz ) { } 
    override GlyphInfo renderChar( size_t ch ) { }
    @property uint baseLineHeight() { }
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
    static lib_inited = false;
    static FT_Library ft;

    FT_Face face;

    /++
        конструктор так то
        Params:
        fontname = полное имя загружаемого шрифта (вместе с путём)
     +/
    this( string fontname )
    {
        if( !lib_inited )
        {
            if( FT_Init_FreeType( &ft ) )
                throw new DTException( "Couldn't init freetype library" );
            debug log.info( "lib loaded" );
            lib_inited = true;
        }

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
        auto ret = GlyphInfo( irect( g.bitmap_left, -g.bitmap_top, 
                g.bitmap.width, g.bitmap.rows ),
                ivec2( cast(int)(g.advance.x >> 6), cast(int)(g.advance.y >> 6) ) );
        ret.buffer.length = ret.rect.w * ret.rect.h;
        foreach( i, ref buf; ret.buffer  )
                buf = g.bitmap.buffer[i];
        return ret;
    }

    @property override uint baseLineHeight() { return face.height; }

    ~this()
    {
        debug log.Debug( "FreeTypeRender destructor start" );
        FT_Done_Face( face );
        debug log.info( "font done" );
        if( lib_inited )
        {
            FT_Done_FreeType( ft );
            debug log.info( "lib done" );
        }
        debug log.Debug( "FreeTypeRender destructor end" );
    }
}

}

/++
 информация об отрисовываемом текте
 +/
struct TextData
{
    wstring str=""; /// как таковой текст
    uint height=12; /// высота шрифта
    col4 color=col4(1,1,1,1); /// цвет
    ivec2 pos=ivec2(0,0); /// позиция, согласно шейдеру, в оконных координатах
}

class LineTextRender
{
    GlyphInfo opCall( FontRender fr, in TextData td )
    {
        GlyphInfo res;
        res.buffer.length = 1;
        res.rect = irect( 0, 0, 1, 1 );
        if( td.str == "" ) return res;

        uint th = td.height;
        fr.setSize( th );
        auto pen = ivec2( 0, 0 );

        GlyphInfo[] buf;

        auto min = ivec2( 32000, 32000 );
        auto max = ivec2( -32000, -32000 );

        void findminmax( in irect r )
        {
            if( min.x > r.pos.x ) min.x = r.pos.x;
            auto b = r.size.x + r.pos.x;
            if( max.x < b ) max.x = b;
            if( min.y > r.pos.y ) min.y = r.pos.y;
            b = r.size.y + r.pos.y;
            if( max.y < b ) max.y = b;
        }

        foreach( i, ch; td.str )
        {
            auto g = fr.renderChar( ch );
            g.rect.pt[0] += pen;
            pen += g.next;
            buf ~= g;

            findminmax( g.rect );
        }

        res.rect = irect( min, max - min );
        res.buffer.length = res.rect.w * res.rect.h;

        int xx, yy, grw, grh, grwr, hi, rrw = res.rect.w;
        foreach( g; buf )
        {
            xx = g.rect.x - min.x;
            yy = g.rect.y - min.y;
            grw = g.rect.w;
            grh = g.rect.h;
            foreach( r; 0 .. grh )
            {
                grwr = grw * r;
                hi = ( yy + r ) * rrw + xx;
                foreach( v; 0 .. grw )
                    res.buffer[ hi + v ] = g.buffer[ grwr + v ];
            }
            res.next += g.next;
        }
        res.rect.pt[0] += td.pos;

        return res;
    }
}

struct TextRShape
{
    irect rect;
    ivec2 next;
    RShape plane;
    TextData text;
}

/++
 отрисовка текста
 +/
class TextElement: Element
{
protected:
    TextRShape[] trs;
    FontRender fr;

    LineTextRender ltr;

    int baseline;

    ivec2 oldsize;

    void updateText()
    {
        if( fr is null )
            throw new DTException( "no font render: set font please" );
        foreach( ref v; trs ) 
        { 
            auto g = ltr( fr, v.text );
            v.rect = g.rect;
            v.next = g.next;
            v.plane.fillTexture( g.rect.size, g.buffer );
        }
        debug log.Debug( "update text" );
        
        updateNoRender();
    }

    void updateNoRender()
    {
        int hoffset = 0;
        if( textalign != TextAlign.LEFT )
        {
            int sum = 0;
            foreach( v; trs )
                sum += v.next.x;
            hoffset = ( textalign == TextAlign.RIGHT ) ? 
                rect.w - sum:
                (rect.w - sum) / 2;
        }
        ivec2 offset = ivec2(hoffset,baseline);
        foreach( ref v; trs ) 
        { 
            v.plane.reshape( irect( v.rect.pos + offset, v.rect.size ) );
            v.plane.setColor( v.text.color );
            offset += v.next;
        }

        debug log.Debug( "update no render" );
    }

    TextAlign textalign = TextAlign.LEFT;

public:

    enum TextAlign { LEFT, CENTER, RIGHT };

    this( Element par, bool procEv=false )
    {
        super( par );
        ltr = new LineTextRender();

        draw.connect( (){ 
                foreach( v; trs )
                    v.plane.draw(); 
                } );

        reshape.connect( (r){ 
                if( r.size.x != oldsize.x ||
                    r.size.y != oldsize.y )
                {
                    updateNoRender(); 
                    oldsize = r.size;
                }
                } );

        baseline = cast(int)(rect.h * 0.8);

        processEvent = procEv;

        debug log.Debug( "TextString create" );

    }

    this( Element par, string fontname, bool procEv=false )
    {
        this( par, procEv );
        setFont( fontname );
    }

    void setFont( string fontname )
    {
        version(Windows) 
        { 
            debug log.Debug( "use WINDOWS_WTF" );
            fr = new WindowsTypeRender( fontname );
        }
        else
        {
            debug log.Debug( "use FreeType" );
            fr = FreeTypeRender.get( fontname );
        }
    }

    @property void baseLine( int bl )
    { 
        debug log.Debug( "change baseline: ", baseline, " -> ", bl );
        baseline = bl; 
        updateNoRender();
    }
    @property int baseLine() const { return baseline; }

    @property void textAlign( TextAlign ta )
    {
        debug log.Debug( "change text align: ", textalign, " -> ", ta );
        textalign = ta;
        updateNoRender();
    }
    @property TextAlign textAlign() const { return textalign; }

    void setTextData( in TextData[] td... )
    {
        trs.length = td.length;
        foreach( i, v; td )
        {
            trs[i].text = v;
            if( trs[i].plane is null ) 
                trs[i].plane = new RShape( info.shader );
        }

        updateText();
        debug log.Debug( "SetText: ", td );
    }
}
