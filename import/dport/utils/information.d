module dport.utils.information;

/++ еденица информации +/
struct Information(Type)
{
    /++ сама информация +/
    Type val;
    
    /++ актуальность +/
    float topicality = 0; 
    /++ достоверность +/
    float reliability = 0; 
    /++ полнота +/
    float completeness = 0; 

    /++ возможность доступа +/
    bool access_ability = true;

    alias val this;

    this(E)( E b ) if( is( E : Type ) )
    { val = b; }

    this(E)( E b, float t, float r, float c, bool aa = true )
        if( is( E : Type ) )
    {
        val = b;
        topicality = t;
        reliability = r;
        completeness = c;
        access_ability = aa;
    }

    auto opAssign(E)( E b ) 
        if( is( E : Type ) && !( is( typeof( E.init.val ) ) ) )
    { 
        val = b; 
        return this;
    }

    auto opAssign(E)( Information!E b )
        if( is( E : Type ) )
    {
        access_ability = b.access_ability;
        topicality = b.topicality;
        reliability = b.reliability;
        completeness = b.completeness;

        val = b.val;
        return this;
    }
}

unittest
{
    alias Information!float float_info;
    auto a = float_info( 5 );
    auto b = float_info( 10 );
    auto c = a + b;
    assert( is( typeof(c) == float ) );
    assert( c == 15 );

    a = 12;
    assert( a.val == 12 );
    b.topicality = 1;
    b.reliability = .5;
    b.completeness = .25;
    a = b;
    assert( a.val == 10 );
    assert( a.topicality == 1 );
    assert( a.reliability == .5 );
    assert( a.completeness == .25 );
}
