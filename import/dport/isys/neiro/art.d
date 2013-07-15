module dport.isys.neiro.art;

import dport.utils.information,
       //dport.utils.system,
       dport.math.types,
       std.math;

//mixin( defaultModuleLogUtils( "ARTDetectorException" ) );
class ARTDetectorException: Exception { this( string msg ){ super( msg ); } }

version(unittest){ import std.stdio; }

float default_diff( float a, float b ){ return abs( a - b ); }
class ART( size_t DIM, TYPE=float, alias DIFF=default_diff ) 
    if( is( typeof(DIFF(TYPE.init, TYPE.init)) : float ) )
{
    alias tensor!(DIM,TYPE) MapType;
    alias Information!size_t RetType;

    float threshold;

    struct Image
    {
        size_t cnt = 0;
        MapType img;

        this( size_t[DIM] imsize )
        {
            img = MapType( imsize );
            img.data[] = 0;
        }

        this( MapType init )
        {
            img = init;
            cnt = 1;
        }

        float diff( in MapType dimg )
        {
            float d = 0;
            foreach( i; 0 .. img.data.length )
                d += DIFF( img.data[i], dimg.data[i] );
            d /= img.data.length;
            return d;
        }

        void add( in MapType newimg )
        {
            if( img.data.length != newimg.data.length )
                throw new ARTDetectorException( "bad in img size" );

            auto newcnt = cnt + 1;
            foreach( i; 0 .. img.data.length )
                img.data[i] = ( img.data[i] * cnt + newimg.data[i] ) / newcnt;
            cnt = newcnt;
        }
    }

    Image[] images;

    this( float th = 0.05 ){ threshold = th; }

    RetType opCall( MapType img )
    {
        float min_diff = float.max-1;
        size_t img_no = 0;

        foreach( i, saved; images )
        {
            auto cdiff = saved.diff( img );
            if( cdiff < min_diff )
            {
                min_diff = cdiff;
                img_no = i;
            }
        }

        RetType rt;
        rt.topicality = 1;

        if( min_diff <= threshold )
        {
            images[img_no].add( img );
            rt.val = img_no;
            rt.completeness = 1.0 - min_diff;
        }
        else
        {
            images ~= Image( img );
            rt.val = images.length-1;
            rt.completeness = 1;
        }

        return rt;
    }
}

unittest
{
    alias ART!(2,real,(a,b){ return (a-b)^^2; }) ART_m2;
    auto map1 = tensor!(2,real)( [ 3, 3 ] );
    map1.data[] = [ .1L, 0, 0,
                 .1, .1, 0,
                  0,  0, .1 ];
    auto test = new ART_m2;
    assert( test( map1 ).val == 0, "init map1" );
    assert( test( map1 ).val == 0, "first map1 test" );
    map1.data[] = [ .09L, 0, 0,
                    .1, .1, 0,
                    0,  0, .1 ];
    assert( test( map1 ).val == 0, "second map1 test" );
    map1.data[] = [ .0L, 1, 0,
                    .1, .1, 0,
                    1,  0, .1 ];
    assert( test( map1 ).val == 1, "init map2" );
    map1.data[] = [ .0L, 1.1, 0,
                    .1, .1, 0,
                    1,  0, .1 ];
    assert( test( map1 ).val == 1, "first test map2" );
}
