module dport.gl.loader;

//import dport.math.types;
import dport.utils.logsys;

private import std.stdio, std.xml, std.conv, std.string;

mixin( defaultModuleLogUtils("LoaderException") );

struct Source
{
    float[] data;
    // apn - acessor params names
    // apn.length - float per element
    string apn; 
}

struct Model
{
    Source[string] src;
}

struct Scene
{
    Model[string] model;
}

Scene colladaLoader( string fname )
{
    string s, buf;
    auto f = File( fname,"r" );
    while( f.readln( buf ) )
        s ~= buf;
    f.close();

    check(s);

    return colladaParser( s );
}

Scene colladaParser( string xmlsrc )
{
    Scene scene;
    auto xml = new DocumentParser(xmlsrc);
    xml.onStartTag["geometry"] = ( ElementParser xml )
    {
        string mname = xml.tag.attr["name"];
        Model model;
        xml.onStartTag["mesh"] = ( ElementParser xml )
        {
            Source[string] model_src;
            xml.onStartTag["source"] = ( ElementParser xml )
            {
                string nn = xml.tag.attr["id"];
                Source src;
                xml.onStartTag["float_array"] = ( ElementParser xml )
                { src.data.length = to!size_t( xml.tag.attr["count"] ); };
                xml.onEndTag["float_array"] = ( in Element e )
                {
                    foreach( i, num; e.text().split(" ") )
                        src.data[i] = to!float( num );
                };
                xml.onStartTag["technique_common"] = ( ElementParser xml )
                {
                    xml.onStartTag["accessor"] = ( ElementParser xml )
                    {
                        xml.onStartTag["param"] = ( ElementParser xml )
                        { src.apn ~= xml.tag.attr["name"].toLower(); };
                        xml.parse();
                    };
                    xml.parse();
                };
                xml.parse();
                model_src[nn] = src;
            };
            xml.onStartTag["vertices"] = ( ElementParser xml )
            {
                string id = xml.tag.attr["id"];
                xml.onStartTag["input"] = ( ElementParser xml )
                { model_src[id] = model_src[xml.tag.attr["source"][1 .. $]]; };
                xml.parse();
            };
            struct pinput
            {
                string sem;
                string src;
                uint offset;
            }
            pinput[] pi;
            size_t[] pp;
            xml.onStartTag["polylist"] = ( ElementParser xml )
            {
                xml.onStartTag["input"] = ( ElementParser xml )
                {
                    pi ~= pinput( xml.tag.attr["semantic"].toLower(),
                                  xml.tag.attr["source"][1 .. $],
                                to!uint(xml.tag.attr["offset"])
                                );
                };
                xml.onEndTag["vcount"] = ( in Element e )
                {
                    try
                    {
                    foreach( num; e.text().split(" ") )
                        if( to!uint(num) != 3 )
                            throw new LoaderException( "not triangle polygon detected" );
                    }
                    catch( LoaderException le )
                        writeln( "loader exception" );
                    catch( Exception e )
                    {
                        writeln( e.msg );
                    }
                };
                xml.onEndTag["p"] = ( in Element e )
                {
                    foreach( num; e.text().split(" ") )
                        pp ~= to!size_t( num );
                };
                xml.parse();
            };
            xml.parse();

            foreach( input; pi )
                model.src[input.sem] = Source( [], model_src[input.src].apn );

            for( size_t i=0; i < pp.length; i+=pi.length )
                foreach( inp; pi )
                {
                    size_t ds = model_src[inp.src].apn.length;
                    foreach( ic; 0 .. ds )
                        model.src[inp.sem].data ~= model_src[inp.src].data[ pp[i+inp.offset]*ds + ic ];
                }
        };
        xml.parse();
        scene.model[ mname ] = model;
    };
    xml.parse();

    return scene;
}
