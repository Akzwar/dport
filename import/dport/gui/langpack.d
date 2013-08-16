module dport.gui.langpack;

import std.conv;

import dport.utils.system;
mixin( defaultModuleLogUtils( "LangPackException" ) );

final class LangPack
{
private:
    wstring[string][string] data;

public:
    string cur = "en";

    this( in wstring[string][string] pack = null ) 
    { if( pack !is null ) setData(pack); }

    void setData( in wstring[string][string] pack )
    { 
        foreach( key, tr; pack )
        {
            foreach( lang, word; tr )
                data[key][lang] = word;
            data[key].rehash;
        }
        data.rehash;
    }

    wstring opIndex( string key ) const { return this[cur,key]; }

    wstring opIndex( string lang, string key ) const
    {
        auto tr = key in data;
        if( tr !is null ) 
        {
            auto word = lang in *tr;
            if( word ) return *word;
            else return to!wstring( "# no tr [" ~ lang ~ "]:[" ~ key ~ "]" );
        }
        else return to!wstring( "# no key [" ~ key ~ "]" );
    }
}

unittest
{
    auto lp = new LangPack( 
              [ "start"    : [ "en": "start",    "ru": "старт"     ],
                "stop"     : [ "en": "stop",     "ru": "стоп"      ],
                "settings" : [ "en": "settings", "ru": "настройки" ],
                "exit"     : [ "en": "exit",     "ru": "выход"     ],
                "ololo"    : [ "en": "okda" ],
               ] );

    lp.cur = "ru";
    assert( lp["settings"] == "настройки" );
    assert( lp["fr","hello"] == "# no key [hello]" );
    assert( lp["exit"] == "выход" );
    assert( lp["en","exit"] == "exit" );
    assert( lp["ololo"] == "# no tr [ru]:[ololo]" );
    assert( lp["en","ololo"] == "okda" );
}
